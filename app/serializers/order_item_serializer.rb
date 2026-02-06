class OrderItemSerializer
  include FastJsonapi::ObjectSerializer

  attributes :id, :product_sku, :quantity, :price_byn, :name, :image_url
end
