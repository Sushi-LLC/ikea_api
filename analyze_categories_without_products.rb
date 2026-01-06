#!/usr/bin/env ruby
# Скрипт для анализа категорий без продуктов

categories_without_products = Category.left_joins(:products)
  .where(products: { id: nil })
  .order(:name)

total = categories_without_products.count

puts "=== КАТЕГОРИИ БЕЗ ПРОДУКТОВ ==="
puts "Всего: #{total}"
puts ""

# Группируем по типам ID
uuid_categories = []
numeric_categories = []
other_categories = []

categories_without_products.each do |cat|
  if cat.ikea_id.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    uuid_categories << cat
  elsif cat.ikea_id.match?(/^\d+$/)
    numeric_categories << cat
  else
    other_categories << cat
  end
end

puts "📊 СТАТИСТИКА:"
puts "  - UUID категории: #{uuid_categories.count}"
puts "  - Числовые ID: #{numeric_categories.count}"
puts "  - Другие форматы: #{other_categories.count}"
puts ""

puts "=== UUID КАТЕГОРИИ (первые 20) ==="
uuid_categories.first(20).each_with_index do |cat, idx|
  puts "#{idx + 1}. #{cat.translated_name.presence || cat.name} (ID: #{cat.ikea_id})"
  puts "   Parent IDs: #{cat.parent_ids.inspect}"
end

puts ""
puts "=== ЧИСЛОВЫЕ ID (первые 20) ==="
numeric_categories.first(20).each_with_index do |cat, idx|
  puts "#{idx + 1}. #{cat.translated_name.presence || cat.name} (ID: #{cat.ikea_id})"
  puts "   Parent IDs: #{cat.parent_ids.inspect}"
end

puts ""
puts "=== ДРУГИЕ ФОРМАТЫ (первые 10) ==="
other_categories.first(10).each_with_index do |cat, idx|
  puts "#{idx + 1}. #{cat.translated_name.presence || cat.name} (ID: #{cat.ikea_id})"
  puts "   Parent IDs: #{cat.parent_ids.inspect}"
end

