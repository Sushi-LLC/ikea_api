class ContentArticleSerializer
  include FastJsonapi::ObjectSerializer

  set_id :slug

  attributes :title, :slug, :excerpt, :content_type, :status,
             :published_at, :tile_blocks,
             :components, :projects, :tags, :pinned, :pinned_position, :active

  attribute :body_blocks do |article|
    article.serialized_body_blocks
  end

  attribute :linked_products, if: Proc.new { |_record, params| params&.dig(:detail) } do |article, params|
    ordered_associations = params[:linked_products_ordered] || article.content_article_products.order(:position)
    products_map = params[:linked_products_map] || {}

    ordered_associations.map do |assoc|
      product = products_map[assoc.product_sku]
      next unless product

      {
        sku: product.sku,
        name: product.name,
        price: product.price,
        images: product.images || [],
        local_images: product.local_images || []
      }
    end.compact
  end

  attribute :linked_categories, if: Proc.new { |_record, params| params&.dig(:detail) } do |article, params|
    ordered_associations = params[:linked_categories_ordered] || article.content_article_categories.order(:position)
    categories_map = params[:linked_categories_map] || {}

    ordered_associations.map do |assoc|
      category = categories_map[assoc.category_id]
      next unless category

      {
        ikea_id: category.ikea_id,
        name: category.name
      }
    end.compact
  end
end
