class ProductSerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :sku, :unique_id, :item_no, :url, :name, :name_ru,
             :collection, :price, :quantity, :weight, :net_weight,
             :package_volume, :package_dimensions, :dimensions,
             :is_parcel, :is_bestseller, :is_popular, :category_id,
             :delivery_type, :delivery_name, :delivery_cost,
             :delivery_reason, :breadcrumbs, :created_at, :updated_at
  
  attribute :variants do |product|
    product.variants || []
  end
  
  attribute :images do |product|
    product.images || []
  end
  
  attribute :local_images do |product|
    product.local_images || []
  end
  
  belongs_to :category, serializer: CategorySerializer, if: Proc.new { |record| record.category.present? }
  
  attribute :category_name do |product|
    product.category&.translated_name || product.category&.name || ''
  end

  attribute :breadcrumbs, if: ->(_record, params) { params&.dig(:detail) } do |product|
    Seo::BreadcrumbsBuilder.for_product(product)
  end
end

