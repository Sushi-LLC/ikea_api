module Seo
  class ProductTitleBuilder
    FALLBACK_KEYS = %w[default default_title default_h1].freeze
    COLOR_KEYS = %w[color colour].freeze
    SIZE_KEYS = %w[size size_ru размер].freeze

    class << self
      def build(product, key: "default")
        return "" unless product

        template = find_template(key)
        return "" unless template&.template_string.present?

        template.template_string.gsub(/{{\s*([^}]+)\s*}}/) do
          placeholder_value(product, Regexp.last_match(1))
        end
      end

      private

      def find_template(key)
        Array.wrap(key.to_s).concat(FALLBACK_KEYS).map(&:presence).compact.uniq.each do |candidate|
          template = ProductTitleTemplate.active.find_by(key: candidate)
          return template if template
        end

        nil
      end

      def placeholder_value(product, raw_placeholder)
        placeholder = raw_placeholder.to_s.strip.downcase

        case placeholder
        when "name"
          product.name_ru.presence || product.name.presence || ""
        when "sku"
          product.sku.to_s
        when "collection"
          product.collection.to_s
        when "category"
          product.primary_category&.translated_name ||
            product.primary_category&.name ||
            ""
        when "color"
          extract_variant_attribute(product, COLOR_KEYS)
        when "size"
          extract_variant_attribute(product, SIZE_KEYS)
        else
          ""
        end
      end

      def extract_variant_attribute(product, keys)
        variant_entries(product).each do |entry|
          next unless entry.respond_to?(:[])

          keys.each do |key|
            value = entry[key] || entry[key.to_sym]
            return value.to_s if value.present?
          end
        end

        ""
      end

      def variant_entries(product)
        raw = product.variants
        return [] if raw.blank?

        case raw
        when Array
          raw
        when Hash
          [raw]
        when String
          parse_variant_string(raw)
        else
          []
        end
      end

      def parse_variant_string(raw)
        JSON.parse(raw)
      rescue JSON::ParserError, TypeError
        []
      end
    end
  end
end
