#!/usr/bin/env ruby
# Скрипт для тестирования методов получения продуктов для категорий без продуктов

require_relative '../config/environment'

# Берем первые 5 категорий без продуктов для теста
test_categories = Category.left_joins(:products)
                         .where(products: { id: nil })
                         .where(is_deleted: [false, nil])
                         .where("categories.ikea_id ~ '^[0-9]+$'")
                         .where.not(url: [nil, ''])
                         .select(:ikea_id, :name, :url)
                         .limit(5)

puts '=' * 80
puts 'Тестирование методов получения продуктов'
puts '=' * 80

results = {
  api_by_id_success: [],
  api_by_id_failed: [],
  html_parsing_success: [],
  html_parsing_failed: [],
  api_by_name_success: [],
  api_by_name_failed: []
}

test_categories.each_with_index do |cat, index|
  puts "\n[#{index + 1}/#{test_categories.count}] Тестирую: #{cat.name} (ID: #{cat.ikea_id})"
  puts "  URL: #{cat.url}"
  
  # Тест 1: API по ID
  begin
    products = IkeaApiService.search_products_by_category(cat.ikea_id, offset: 0, limit: 5)
    if products.any?
      results[:api_by_id_success] << { id: cat.ikea_id, name: cat.name, count: products.count }
      puts "  ✓ API по ID: найдено #{products.count} продуктов"
    else
      results[:api_by_id_failed] << { id: cat.ikea_id, name: cat.name }
      puts "  ✗ API по ID: продуктов не найдено"
    end
  rescue => e
    results[:api_by_id_failed] << { id: cat.ikea_id, name: cat.name, error: e.message }
    puts "  ✗ API по ID: ошибка - #{e.message[0..100]}"
  end
  
  sleep(1) # Задержка между запросами
  
  # Тест 2: HTML парсинг
  if cat.url.present?
    begin
      products = CategoryProductsFetcher.fetch(cat.url, offset: 0, limit: 5)
      if products.any?
        results[:html_parsing_success] << { id: cat.ikea_id, name: cat.name, url: cat.url, count: products.count }
        puts "  ✓ HTML парсинг: найдено #{products.count} продуктов"
      else
        results[:html_parsing_failed] << { id: cat.ikea_id, name: cat.name, url: cat.url }
        puts "  ✗ HTML парсинг: продуктов не найдено"
      end
    rescue => e
      results[:html_parsing_failed] << { id: cat.ikea_id, name: cat.name, url: cat.url, error: e.message[0..100] }
      puts "  ✗ HTML парсинг: ошибка - #{e.message[0..100]}"
    end
  end
  
  sleep(1) # Задержка между запросами
  
  # Тест 3: API по названию
  if cat.name.present?
    begin
      search_service = CategoryProductsSearchService.new
      products = search_service.search(cat, offset: 0, limit: 5, strategies: [:api_by_category_name])
      if products.any?
        results[:api_by_name_success] << { id: cat.ikea_id, name: cat.name, count: products.count }
        puts "  ✓ API по названию: найдено #{products.count} продуктов"
      else
        results[:api_by_name_failed] << { id: cat.ikea_id, name: cat.name }
        puts "  ✗ API по названию: продуктов не найдено"
      end
    rescue => e
      results[:api_by_name_failed] << { id: cat.ikea_id, name: cat.name, error: e.message[0..100] }
      puts "  ✗ API по названию: ошибка - #{e.message[0..100]}"
    end
  end
  
  sleep(2) # Задержка между категориями
end

puts "\n" + '=' * 80
puts 'РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ:'
puts '=' * 80
puts "\n📊 API по ID категории:"
puts "  ✓ Успешно: #{results[:api_by_id_success].count}/#{test_categories.count}"
puts "  ✗ Не найдено/ошибка: #{results[:api_by_id_failed].count}/#{test_categories.count}"

puts "\n📊 HTML парсинг:"
puts "  ✓ Успешно: #{results[:html_parsing_success].count}/#{test_categories.count}"
puts "  ✗ Не найдено/ошибка: #{results[:html_parsing_failed].count}/#{test_categories.count}"

puts "\n📊 API по названию категории:"
puts "  ✓ Успешно: #{results[:api_by_name_success].count}/#{test_categories.count}"
puts "  ✗ Не найдено/ошибка: #{results[:api_by_name_failed].count}/#{test_categories.count}"

if results[:api_by_id_success].any?
  puts "\n✅ Категории, для которых работает API по ID:"
  results[:api_by_id_success].each do |item|
    puts "  - #{item[:id]} | #{item[:name]} (#{item[:count]} продуктов)"
  end
end

if results[:html_parsing_success].any?
  puts "\n✅ Категории, для которых работает HTML парсинг:"
  results[:html_parsing_success].each do |item|
    puts "  - #{item[:id]} | #{item[:name]} (#{item[:count]} продуктов)"
  end
end

if results[:api_by_name_success].any?
  puts "\n✅ Категории, для которых работает API по названию:"
  results[:api_by_name_success].each do |item|
    puts "  - #{item[:id]} | #{item[:name]} (#{item[:count]} продуктов)"
  end
end

puts "\n" + '=' * 80

