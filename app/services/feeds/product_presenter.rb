require "json"

module Feeds
  class ProductPresenter
    attr_reader :product, :settings

    def initialize(product:, settings:)
      @product = product
      @settings = settings
    end

    def valid?
      base_url.present? &&
        link_url.present? &&
        image_url.present? &&
        price_amount.present? &&
        currency.present? &&
        category_id.present?
    end

    def id
      product.sku.presence || product.unique_id.presence || product.id
    end

    def title
      [
        product.name,
        product.name_ru,
        product.collection
      ].find(&:present?) || "Product #{id}"
    end

    def description
      [
        product.content,
        product.content_ru,
        product.short_description,
        product.short_description_ru,
        product.good_info,
        product.good_info_ru,
        product.material_info,
        product.material_info_ru
      ].find(&:present?)&.strip || title
    end

    def link_url
      return unless product.url.present? && base_url.present?

      if product.url =~ /\Ahttps?:\/\//
        product.url
      else
        path = product.url.start_with?("/") ? product.url : "/#{product.url}"
        "#{base_url}#{path}"
      end
    end

    def image_url
      image_urls.first
    end

    def additional_image_urls
      image_urls.drop(1)
    end

    def price_amount
      product.price&.to_d
    end

    def currency
      settings.currency_default&.upcase
    end

    def availability_key
      return @availability_key if defined?(@availability_key)

      qty = product.quantity
      status =
        if qty.present?
          qty.to_i.positive? ? "in_stock" : "out_of_stock"
        else
          "in_stock"
        end

      @availability_key = status
    end

    def availability_for_google
      settings.availability_mapping_hash[availability_key] || availability_key
    end

    def available_for_yandex?
      return true if settings.include_out_of_stock?

      availability_key == "in_stock"
    end

    def category
      product.category
    end

    def category_id
      category&.ikea_id.presence || product.category_id
    end

    def category_name_path
      category&.name
    end

    def product_type
      category_name_path
    end

    def brand
      settings.store_platform_brand
    end

    private

    def base_url
      settings.base_url_root
    end

    def image_urls
      @image_urls ||= begin
        sources = Array(parse_images(product.images)) + Array(parse_images(product.local_images))
        sources = sources.flatten
        sources.map { |url| normalize_url(url) }.compact.uniq
      end
    end

    def parse_images(value)
      return [] if value.blank?

      if value.is_a?(String)
        JSON.parse(value)
      else
        value
      end
    rescue JSON::ParserError
      Array(value)
    end

    def normalize_url(value)
      return nil unless value.present?

      candidate = value.to_s.strip
      return nil if candidate.blank?
      return candidate if candidate =~ /\Ahttps?:\/\//
      return nil unless base_url.present?

      path = candidate.start_with?("/") ? candidate : "/#{candidate}"
      "#{base_url}#{path}"
    end
  end
end
