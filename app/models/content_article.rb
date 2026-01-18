require "json"
require "securerandom"

class ContentArticle < ApplicationRecord
  enum content_type: { tips_ideas: 0, news: 1 }
  enum status: { draft: 0, published: 1, archived: 2 }

  attr_accessor :product_skus_input, :category_ids_input
  attr_writer :components_input, :projects_input, :tags_input, :body_blocks_json, :tile_blocks_json

  has_many :content_article_products, dependent: :destroy
  has_many :content_article_categories, dependent: :destroy
  has_many :linked_products, through: :content_article_products, source: :product
  has_many :linked_categories, through: :content_article_categories, source: :category

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :normalize_slug
  before_validation :normalize_array_fields

  after_save :sync_linked_products
  after_save :sync_linked_categories

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
end
