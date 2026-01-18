require "json"
require "securerandom"

class ContentArticle < ApplicationRecord
  include Rails.application.routes.url_helpers

  BODY_BLOCK_TEMPLATES = [
    {
      id: "text_with_image",
      label: "Текст + широкая картинка",
      slider_enabled: false,
      button_enabled: false,
      image_slots: [
        { name: "hero_image", label: "Широкое изображение" }
      ]
    },
    {
      id: "image_left_text_right",
      label: "Картинка слева, текст справа с кнопкой",
      slider_enabled: true,
      button_enabled: true,
      image_slots: [
        { name: "side_image", label: "Изображение" }
      ]
    },
    {
      id: "image_right_text_left",
      label: "Картинка справа, текст слева с кнопкой",
      slider_enabled: true,
      button_enabled: true,
      image_slots: [
        { name: "side_image", label: "Изображение" }
      ]
    },
    {
      id: "text_images_row",
      label: "Текст, кнопка и две картинки",
      slider_enabled: true,
      button_enabled: true,
      image_slots: [
        { name: "left_image", label: "Левое изображение" },
        { name: "right_image", label: "Правое изображение" }
      ]
    }
  ].freeze
  enum content_type: { tips_ideas: 0, news: 1 }
  enum status: { draft: 0, published: 1, archived: 2 }

  attr_accessor :product_skus_input, :category_ids_input
  attr_writer :components_input, :projects_input, :tags_input, :body_blocks_json, :tile_blocks_json
  attr_accessor :body_block_images_uploads

  has_many :content_article_products, dependent: :destroy
  has_many :content_article_categories, dependent: :destroy
  has_many :linked_products, through: :content_article_products, source: :product
  has_many :linked_categories, through: :content_article_categories, source: :category
  has_many_attached :body_block_images

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :normalize_slug
  before_validation :normalize_array_fields
  before_validation :normalize_body_blocks

  after_save :sync_linked_products
  after_save :sync_linked_categories
  after_save :sync_body_block_images

  scope :published_and_active, -> { where(status: statuses[:published], active: true) }
  scope :ordered_for_feed, -> { order(pinned: :desc, pinned_position: :asc, published_at: :desc) }
  scope :visible, -> { published_and_active.order(pinned: :desc, pinned_position: :asc, published_at: :desc) }
  scope :with_component, ->(value) { where("components @> ?", Array(value).to_json) if value.present? }
  scope :with_project, ->(value) { where("projects @> ?", Array(value).to_json) if value.present? }
  scope :with_tag, ->(value) { where("tags @> ?", Array(value).to_json) if value.present? }
  scope :pinned, -> { where(pinned: true) }

  def components_input
    @components_input || components.to_a.join("\n")
  end

  def components_input=(value)
    self.components = normalize_array_value(value)
  end

  def projects_input
    @projects_input || projects.to_a.join("\n")
  end

  def projects_input=(value)
    self.projects = normalize_array_value(value)
  end

  def tags_input
    @tags_input || tags.to_a.join("\n")
  end

  def tags_input=(value)
    self.tags = normalize_array_value(value)
  end

  def body_blocks_json
    @body_blocks_json || JSON.pretty_generate(body_blocks || [])
  rescue JSON::ParserError
    body_blocks.to_s
  end

  def body_blocks_json=(value)
    self.body_blocks = parse_json_array(value)
  end

  def tile_blocks_json
    @tile_blocks_json || JSON.pretty_generate(tile_blocks || [])
  rescue JSON::ParserError
    tile_blocks.to_s
  end

  def tile_blocks_json=(value)
    self.tile_blocks = parse_json_array(value)
  end

  def product_skus_input
    return @product_skus_input if instance_variable_defined?(:@product_skus_input)

    linked_product_skus.join("\n")
  end

  def category_ids_input
    return @category_ids_input if instance_variable_defined?(:@category_ids_input)

    linked_category_ids.join("\n")
  end

  def to_param
    slug
  end

  def linked_product_skus
    content_article_products.order(:position).pluck(:product_sku)
  end

  def linked_category_ids
    content_article_categories.order(:position).pluck(:category_id)
  end

  def body_blocks_for_admin
    body_blocks.map { |block| decorate_block(block, include_preview: true) }
  end

  def serialized_body_blocks
    all_category_ids = (button_category_ids + slider_category_ids).compact.uniq
    categories = Category.where(ikea_id: all_category_ids).index_by(&:ikea_id)
  
    body_blocks.map do |block|
      block_data = decorate_block(block, include_preview: true)
  
      button_id = block_data["button_category_id"]
      slider_id = block_data["slider_category_id"]
  
      block_data["button_category"] = category_payload(categories[button_id])
      block_data["slider_category"] = category_payload(categories[slider_id])
  
      # ✅ гарантируем тип массива (на случай старых записей)
      block_data["slider_product_skus"] = Array.wrap(block_data["slider_product_skus"]).map(&:to_s)
  
      block_data
    end
  end

  def button_category_ids
    body_blocks.map { |block| block["button_category_id"] }.compact
  end

  def slider_category_ids
    body_blocks.map { |block| block["slider_category_id"] }.compact
  end

  private

  def normalize_slug
    return if title.blank? && slug.present?

    base_slug = slug.present? ? slug : title
    normalized_base = normalize_slug_candidate(base_slug)
    normalized_base = "article-#{SecureRandom.hex(4)}" if normalized_base.blank?
    candidate = normalized_base

    counter = 2
    while ContentArticle.where.not(id: id).exists?(slug: candidate)
      candidate = "#{normalized_base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end

  def normalize_array_fields
    self.components = normalize_array_value(components)
    self.projects = normalize_array_value(projects)
    self.tags = normalize_array_value(tags)
  end

  def normalize_body_blocks
    normalized_blocks = Array.wrap(body_blocks).map.with_index do |block, index|
      normalize_block(block, index)
    end
    self.body_blocks = normalized_blocks
  end

  def normalize_block(raw_block, index)
    template = block_template_for(raw_block&.fetch("type", nil))
  
    images = template[:image_slots].map do |slot|
      existing_image = Array.wrap(raw_block&.fetch("images", [])).find { |image| image["slot"] == slot[:name] }
      {
        "slot" => slot[:name],
        "signed_id" => existing_image&.dig("signed_id").presence,
        "filename" => existing_image&.dig("filename").presence
      }
    end
  
    slider_category_id =
      if template[:slider_enabled]
        raw_block&.fetch("slider_category_id", nil).presence
      end
  
    slider_product_skus =
      if template[:slider_enabled]
        Array.wrap(raw_block&.fetch("slider_product_skus", [])).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      else
        []
      end
  
    {
      "type" => template[:id],
      "content" => raw_block&.fetch("content", "").to_s,
      "button_text" => raw_block&.fetch("button_text", "").to_s,
      "button_category_id" => raw_block&.fetch("button_category_id", nil).presence,
      "slider_enabled" => template[:slider_enabled],
      "button_enabled" => template[:button_enabled],
  
      "slider_category_id" => slider_category_id,
      "slider_product_skus" => slider_product_skus,
  
      "images" => images,
      "position" => index
    }
  end

  def block_template_for(type)
    BODY_BLOCK_TEMPLATES.find { |template| template[:id] == type } || default_block_template
  end

  def default_block_template
    BODY_BLOCK_TEMPLATES.first
  end

  def decorate_block(block, include_preview: false)
    block_data = block.deep_dup
    images = Array.wrap(block_data["images"])
    block_data["images"] = images.map do |image|
      decorate_image(image, include_preview: include_preview)
    end
    block_data
  end

  def decorate_image(image, include_preview:)
    payload = {
      "slot" => image["slot"],
      "signed_id" => image["signed_id"]
    }
  
    payload["filename"] = image["filename"] if image["filename"].present?
  
    if include_preview && image["signed_id"].present?
      payload["url"] = preview_url_for(image["signed_id"])
    end
  
    payload
  end

  def category_payload(category)
    return nil unless category

    {
      "ikea_id" => category.ikea_id,
      "name" => category.name
    }
  end

  def preview_url_for(signed_id)
    blob = blob_for_signed_id(signed_id)
    return nil unless blob

    rails_blob_url(blob, host: default_url_host)
  rescue ArgumentError
    nil
  end

  def blob_for_signed_id(signed_id)
    return nil unless signed_id.present?

    ActiveStorage::Blob.find_signed(signed_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    nil
  end

  def default_url_host
    default_host = Rails.application.routes.default_url_options[:host]
    return default_host if default_host.present?

    ENV["DEFAULT_URL_HOST"].presence || ENV["API_HOST"].presence || "http://localhost:3000"
  end

  def normalize_array_value(value)
    return [] if value.blank?
    if value.is_a?(Array)
      value.flat_map { |item| normalize_array_entry(item) }.reject(&:blank?)
    else
      value.to_s.split(/[\n,]+/).map { |item| normalize_array_entry(item) }.reject(&:blank?)
    end
  end

  def parse_json_array(value)
    return [] if value.blank?
    parsed = JSON.parse(value)
    parsed.is_a?(Array) ? parsed : [parsed]
  rescue JSON::ParserError
    []
  end

  def normalize_array_entry(value)
    value.to_s.strip
  end

  def normalize_slug_candidate(value)
    value.to_s.parameterize
  end

  def sync_linked_products
    return unless defined?(@product_skus_input)

    parsed_skus = normalize_array_value(@product_skus_input)
    content_article_products.delete_all
    parsed_skus.each_with_index do |sku, index|
      content_article_products.create!(
        product_sku: sku,
        position: index,
        source: :manual
      )
    end
  end

  def sync_linked_categories
    return unless defined?(@category_ids_input)

    parsed_ids = normalize_array_value(@category_ids_input)
    content_article_categories.delete_all
    parsed_ids.each_with_index do |category_id, index|
      content_article_categories.create!(
        category_id: category_id,
        position: index
      )
    end
  end

  def sync_body_block_images
    desired_signed_ids = referenced_block_image_signed_ids
    current_signed_ids = body_block_images.map { |blob| blob.signed_id }

    purge_stale_block_images(current_signed_ids - desired_signed_ids)
    (desired_signed_ids - current_signed_ids).each do |signed_id|
      attach_signed_blob(signed_id)
    end
  end

  def referenced_block_image_signed_ids
    Array.wrap(body_blocks).flat_map { |block| Array.wrap(block.fetch("images", [])).map { |image| image["signed_id"] } }.compact
  end

  def purge_stale_block_images(outdated_signed_ids)
    return if outdated_signed_ids.empty?

    attachments = body_block_images.attachments.select do |attachment|
      outdated_signed_ids.include?(attachment.blob.signed_id)
    end
    attachments.each(&:purge_later)
  end

  def attach_signed_blob(signed_id)
    return if signed_id.blank?

    blob = blob_for_signed_id(signed_id)
    return unless blob

    body_block_images.attach(blob)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    nil
  end
end
