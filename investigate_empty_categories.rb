#!/usr/bin/env ruby
# Скрипт для выяснения причин отсутствия продуктов

require 'json'

categories_without_products = Category.left_joins(:products)
  .where(products: { id: nil })
  .order(:name)

total = categories_without_products.count

puts "=== АНАЛИЗ КАТЕГОРИЙ БЕЗ ПРОДУКТОВ ==="
puts "Всего: #{total}"
puts ""

# Проверяем, есть ли дочерние категории
categories_with_children = []
categories_without_children = []

categories_without_products.each do |cat|
  children_count = Category.where(
    "parent_ids::text LIKE ? OR parent_ids::text LIKE ?",
    "%\"#{cat.ikea_id}\"%",
    "%#{cat.ikea_id}%"
  ).where.not(ikea_id: cat.ikea_id).count
  
  if children_count > 0
    categories_with_children << { category: cat, children_count: children_count }
  else
    categories_without_children << cat
  end
end

puts "📊 СТАТИСТИКА:"
puts "  - Категории с дочерними: #{categories_with_children.count}"
puts "  - Категории без дочерних: #{categories_without_children.count}"
puts ""

# Проверяем, были ли эти категории обработаны в последних задачах парсинга
puts "=== ПРОВЕРКА ОБРАБОТКИ В ПАРСЕРАХ ==="
recent_tasks = ParserTask.where(task_type: 'products')
  .order(created_at: :desc)
  .limit(5)

if recent_tasks.any?
  puts "Последние задачи парсинга продуктов:"
  recent_tasks.each do |task|
    puts "  - ID: #{task.id}, Создано: #{task.created_at}, Обработано: #{task.processed}, Ошибок: #{task.errors}"
  end
else
  puts "  Нет задач парсинга продуктов"
end

puts ""
puts "=== КАТЕГОРИИ БЕЗ ДОЧЕРНИХ (первые 30) ==="
categories_without_children.first(30).each_with_index do |cat, idx|
  # Проверяем, является ли ID числовым
  is_numeric = cat.ikea_id.match?(/^\d+$/)
  is_uuid = cat.ikea_id.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
  is_composite = cat.ikea_id.include?('/')
  
  type = if is_uuid
    "UUID"
  elsif is_numeric
    "Числовой"
  elsif is_composite
    "Составной"
  else
    "Другой"
  end
  
  puts "#{idx + 1}. #{cat.translated_name.presence || cat.name} (ID: #{cat.ikea_id})"
  puts "   Тип: #{type}"
  puts "   Parent IDs: #{cat.parent_ids.inspect}"
end

puts ""
puts "=== КАТЕГОРИИ С ДОЧЕРНИМИ (первые 10) ==="
categories_with_children.first(10).each_with_index do |item, idx|
  cat = item[:category]
  puts "#{idx + 1}. #{cat.translated_name.presence || cat.name} (ID: #{cat.ikea_id})"
  puts "   Дочерних категорий: #{item[:children_count]}"
  puts "   Parent IDs: #{cat.parent_ids.inspect}"
end

# Проверяем, есть ли в логах ошибки для этих категорий
puts ""
puts "=== ПРОВЕРКА ЛОГОВ (последние ошибки парсинга) ==="
# Это можно проверить через ParserTask, если там есть информация об ошибках

