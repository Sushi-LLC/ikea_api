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
  
  # Запускаем задачу парсинга
  task = ParserTask.create!(
    task_type: 'products',
    status: 'pending',
    limit: nil # Без лимита, обрабатываем все категории
  )
  
  # Запускаем задачу для каждой категории
  categories_to_process.each do |category|
    ParseProductsJob.perform_later(
      category_id: category.ikea_id,
      task_id: task.id
    )
  end
  
  puts "✅ Создана задача ##{task.id} для обработки #{categories_to_process.count} категорий"
  puts "   Категории будут обработаны в фоновом режиме"
else
  puts "ℹ️  Нет категорий для обработки"
  puts "   Все доступные категории уже обработаны или требуют прокси"
end

