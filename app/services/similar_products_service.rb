class SimilarProductsService
  def self.for(product:, limit: 8)
    return [] unless product

    scope = Product.where('quantity > 0').where.not(sku: product.sku)

    if product.collection.present?
      scope = scope.where(collection: product.collection)
    else
      scope = scope.where(category_id: product.category_id)
    end

    scope.limit(limit)
  end
end
