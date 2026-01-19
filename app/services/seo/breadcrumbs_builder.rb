module Seo
  class BreadcrumbsBuilder
    PRODUCT_ENTITY_TYPE = "product".freeze

    def self.for_product(product)
      new(product).build
    end

    def initialize(product)
      @product = product
    end

    def build
      return [] unless product

      rule = BreadcrumbRule.active_for(PRODUCT_ENTITY_TYPE)
      return [] unless rule

      category = product.primary_category
      return [] unless category

      case rule.rule_type
      when "by_primary_category_tree"
        build_tree(category)
      when "by_primary_category_only"
        build_primary(category)
      else
        []
      end
    end

    private

    attr_reader :product

    def build_tree(category)
      ancestor_ids = Category.normalize_parent_ids(category.parent_ids)
      ancestor_ids = ancestor_ids.map(&:to_s).reject(&:blank?) if ancestor_ids.present?

      breadcrumb_categories = []
      if ancestor_ids.present?
        ancestors = Category.where(ikea_id: ancestor_ids).index_by(&:ikea_id)
        ancestor_ids.each do |ikea_id|
          ancestor = ancestors[ikea_id]
          breadcrumb_categories << ancestor if ancestor
        end
      end

      breadcrumb_categories << category
      breadcrumb_categories.uniq { |cat| cat.ikea_id }.map { |cat| breadcrumb_entry(cat) }
    end

    def build_primary(category)
      [breadcrumb_entry(category)]
    end

    def breadcrumb_entry(category)
      {
        title: category.translated_name,
        url: category_url(category)
      }
    end

    def category_url(category)
      "/category/#{category.ikea_id}"
    end
  end
end
