# Скрипт для повторной обработки категорий без продуктов
# Использование: bundle exec rails runner reprocess_unprocessed_categories.rb

puts "=== ПОВТОРНАЯ ОБРАБОТКА НЕОБРАБОТАННЫХ КАТЕГОРИЙ ==="
puts ""

# Находим категории без продуктов
categories_for_parsing = Category.not_deleted
categories_with_products = Category.joins(:products).distinct.pluck(:id)
categories_without_products = categories_for_parsing.where.not(id: categories_with_products)

puts "📊 Найдено необработанных категорий: #{categories_without_products.count}"
puts ""

# Фильтруем UUID категории без прокси
proxy_list = ENV.fetch('PROXY_LIST', '').split(',').map(&:strip).reject(&:empty?)
categories_to_process = categories_without_products.select do |cat|
  is_uuid = cat.ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) || 
            cat.ikea_id.to_s.include?('/')
  !is_uuid || proxy_list.any?
end

puts "📋 Категорий для обработки (после фильтрации): #{categories_to_process.count}"
puts ""

if categories_to_process.any?
  puts "🚀 Запускаем задачу парсинга для необработанных категорий..."
  puts ""
  
  # Запускаем одну задачу парсинга для всех категорий
  # ParseProductsJob обработает все категории из Category.not_deleted
  # Но мы можем запустить задачу без лимита, чтобы обработать все
  puts "   Запускаем ParseProductsJob без лимита..."
  ParseProductsJob.perform_later(limit: nil)
  
  puts "✅ Задача парсинга запущена в фоновом режиме"
  puts "   Будет обработано #{categories_to_process.count} необработанных категорий"
  puts "   (всего категорий для обработки: #{categories_for_parsing.count})"
else
  puts "ℹ️  Нет категорий для обработки"
  puts "   Все доступные категории уже обработаны или требуют прокси"
end

