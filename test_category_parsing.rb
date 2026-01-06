#!/usr/bin/env ruby
# Тест парсинга конкретных категорий

require_relative 'app/services/ikea_api_service'

# Берем несколько категорий без продуктов для теста
test_categories = [
  { id: '48982', name: 'Приборы для KNOXHULT' },
  { id: '700403', name: 'Кухонная техника ÄSPINGE' },
  { id: '50374', name: 'Кухонная техника ENHET' },
  { id: '33547', name: 'Аксессуары для столешниц' },
  { id: '20621', name: 'Аксессуары для чая' }
]

puts "=== ТЕСТ ПАРСИНГА КАТЕГОРИЙ ==="
puts ""

test_categories.each do |cat_info|
  category_id = cat_info[:id]
  category_name = cat_info[:name]
  
  puts "📦 Категория: #{category_name} (ID: #{category_id})"
  
  begin
    # Пробуем получить продукты через API
    products = IkeaApiService.search_products_by_category(category_id)
    
    if products.any?
      puts "   ✅ API вернул #{products.count} продуктов"
      puts "   Первые 3 продукта:"
      products.first(3).each do |product|
        puts "     - #{product['name']} (SKU: #{product['productNumber']})"
      end
    else
      puts "   ⚠️  API вернул пустой результат"
      
      # Проверяем, может быть это подкатегория, которая не должна иметь продуктов
      category = Category.find_by(ikea_id: category_id)
      if category
        children_count = Category.where(
          "parent_ids::text LIKE ? OR parent_ids::text LIKE ?",
          "%\"#{category_id}\"%",
          "%#{category_id}%"
        ).where.not(ikea_id: category_id).count
        
        if children_count > 0
          puts "   ℹ️  Это родительская категория с #{children_count} дочерними категориями"
        end
      end
    end
  rescue => e
    puts "   ❌ Ошибка при запросе: #{e.class} - #{e.message}"
  end
  
  puts ""
end

