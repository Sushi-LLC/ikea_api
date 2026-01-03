# Сериализатор для карты категорий
# Возвращает категории с переведенными именами, ссылками и продуктами
class CategoryMapSerializer
  include FastJsonapi::ObjectSerializer
  
  set_id :ikea_id
  
  attributes :ikea_id, :name, :translated_name, :url
  
  attribute :products do |category|
    category.products.map do |product|
      {
        sku: product.sku,
        name: product.name,
        name_ru: product.name_ru || product.name,
        url: product.url
      }
    end
  end
end

