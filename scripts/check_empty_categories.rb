#!/usr/bin/env ruby
# Скрипт для проверки категорий без продуктов на проде

categories_without_products = Category.left_joins(:products)
                                     .where(products: { id: nil })
                                     .where(is_deleted: [false, nil])
                                     .select(:ikea_id, :name, :translated_name, :url, :is_popular, :is_important)
                                     .order(:name)

total = categories_without_products.count
puts '=' * 80
puts 'Проверка категорий без продуктов'
puts '=' * 80
puts "\nВсего категорий без продуктов: #{total}"

if total > 0
  numeric_ids = []
  uuid_ids = []
  other_ids = []
  
  categories_without_products.each do |cat|
    id_str = cat.ikea_id.to_s
    if id_str.match?(/^\d+$/)
      numeric_ids << cat
    elsif id_str.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      uuid_ids << cat
    else
      other_ids << cat
    end
  end
  
  puts "\n📊 Статистика по типам ID:"
  puts "  - Числовые ID: #{numeric_ids.count}"
  puts "  - UUID: #{uuid_ids.count}"
  puts "  - Другие форматы: #{other_ids.count}"
  
  with_url = categories_without_products.where.not(url: [nil, '']).count
  without_url = categories_without_products.where(url: [nil, '']).count
  
  puts "\n📊 Статистика по URL:"
  puts "  - С URL: #{with_url}"
  puts "  - Без URL: #{without_url}"
  
  popular_empty = categories_without_products.where(is_popular: true).count
  important_empty = categories_without_products.where(is_important: true).count
  
  puts "\n📊 Важные категории без продуктов:"
  puts "  - Популярные: #{popular_empty}"
  puts "  - Важные (is_important): #{important_empty}"
  
  puts "\n📋 Примеры категорий с числовыми ID (первые 10):"
  numeric_ids.first(10).each do |cat|
    url_info = cat.url.present? ? "✓ URL: #{cat.url[0..50]}..." : "✗ Нет URL"
    puts "  - #{cat.ikea_id} | #{cat.name} | #{url_info}"
  end
  
  puts "\n📋 Примеры категорий с UUID (первые 10):"
  uuid_ids.first(10).each do |cat|
    url_info = cat.url.present? ? "✓ URL: #{cat.url[0..50]}..." : "✗ Нет URL"
    puts "  - #{cat.ikea_id} | #{cat.name} | #{url_info}"
  end
  
  if important_empty > 0
    puts "\n⚠️  ВАЖНЫЕ категории без продуктов:"
    categories_without_products.where(is_important: true).each do |cat|
      puts "  - #{cat.ikea_id} | #{cat.name} | URL: #{cat.url || 'нет'}"
    end
  end
end
puts '=' * 80

