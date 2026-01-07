namespace :categories do
  desc "Проверить категории без продуктов на проде"
  task check_empty: :environment do
    puts "=" * 80
    puts "Проверка категорий без продуктов"
    puts "=" * 80
    
    # Находим все категории без продуктов
    categories_without_products = Category.left_joins(:products)
                                         .where(products: { id: nil })
                                         .where(is_deleted: [false, nil])
                                         .select(:ikea_id, :name, :translated_name, :url, :is_popular, :is_important)
                                         .order(:name)
    
    total = categories_without_products.count
    puts "\nВсего категорий без продуктов: #{total}"
    
    if total > 0
      puts "\n" + "=" * 80
      puts "Детальная информация:"
      puts "=" * 80
      
      # Группируем по типу ID
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
      
      puts "\n📋 Категории с числовыми ID (первые 20):"
      numeric_ids.first(20).each do |cat|
        url_info = cat.url.present? ? "✓ URL: #{cat.url}" : "✗ Нет URL"
        popular = cat.is_popular ? "⭐ Популярная" : ""
        important = cat.is_important ? "🔝 Важная" : ""
        puts "  - #{cat.ikea_id} | #{cat.name} | #{url_info} #{popular} #{important}"
      end
      
      if numeric_ids.count > 20
        puts "  ... и еще #{numeric_ids.count - 20} категорий"
      end
      
      puts "\n📋 Категории с UUID (первые 20):"
      uuid_ids.first(20).each do |cat|
        url_info = cat.url.present? ? "✓ URL: #{cat.url}" : "✗ Нет URL"
        popular = cat.is_popular ? "⭐ Популярная" : ""
        important = cat.is_important ? "🔝 Важная" : ""
        puts "  - #{cat.ikea_id} | #{cat.name} | #{url_info} #{popular} #{important}"
      end
      
      if uuid_ids.count > 20
        puts "  ... и еще #{uuid_ids.count - 20} категорий"
      end
      
      puts "\n📋 Категории с другими форматами ID (первые 20):"
      other_ids.first(20).each do |cat|
        url_info = cat.url.present? ? "✓ URL: #{cat.url}" : "✗ Нет URL"
        popular = cat.is_popular ? "⭐ Популярная" : ""
        important = cat.is_important ? "🔝 Важная" : ""
        puts "  - #{cat.ikea_id} | #{cat.name} | #{url_info} #{popular} #{important}"
      end
      
      if other_ids.count > 20
        puts "  ... и еще #{other_ids.count - 20} категорий"
      end
      
      # Статистика по наличию URL
      with_url = categories_without_products.where.not(url: [nil, '']).count
      without_url = categories_without_products.where(url: [nil, '']).count
      
      puts "\n📊 Статистика по URL:"
      puts "  - С URL: #{with_url}"
      puts "  - Без URL: #{without_url}"
      
      # Популярные и важные категории
      popular_empty = categories_without_products.where(is_popular: true).count
      important_empty = categories_without_products.where(is_important: true).count
      
      puts "\n📊 Важные категории без продуктов:"
      puts "  - Популярные: #{popular_empty}"
      puts "  - Важные (is_important): #{important_empty}"
      
      if important_empty > 0
        puts "\n⚠️  ВАЖНЫЕ категории без продуктов:"
        categories_without_products.where(is_important: true).each do |cat|
          puts "  - #{cat.ikea_id} | #{cat.name} | URL: #{cat.url || 'нет'}"
        end
      end
    end
    
    puts "\n" + "=" * 80
    puts "Проверка завершена"
    puts "=" * 80
  end
  
  desc "Проверить возможности получения продуктов для категорий без продуктов"
  task analyze_empty: :environment do
    puts "=" * 80
    puts "Анализ возможностей получения продуктов для категорий без продуктов"
    puts "=" * 80
    
    categories_without_products = Category.left_joins(:products)
                                         .where(products: { id: nil })
                                         .where(is_deleted: [false, nil])
                                         .select(:ikea_id, :name, :translated_name, :url, :is_popular, :is_important)
                                         .order(:name)
                                         .limit(50) # Ограничиваем для теста
    
    puts "\nПроверяем первые 50 категорий без продуктов..."
    puts "=" * 80
    
    results = {
      api_by_id_success: [],
      api_by_id_failed: [],
      api_by_name_success: [],
      api_by_name_failed: [],
      html_parsing_success: [],
      html_parsing_failed: [],
      no_url: [],
      total_checked: 0
    }
    
    categories_without_products.each do |cat|
      results[:total_checked] += 1
      id_str = cat.ikea_id.to_s
      
      puts "\n[#{results[:total_checked]}/50] Проверяю: #{cat.name} (#{id_str})"
      
      # Проверка 1: API по ID (только для числовых ID)
      if id_str.match?(/^\d+$/)
        begin
          products = IkeaApiService.search_products_by_category(cat.ikea_id, offset: 0, limit: 5)
          if products.any?
            results[:api_by_id_success] << { id: id_str, name: cat.name, count: products.count }
            puts "  ✓ API по ID: найдено #{products.count} продуктов"
          else
            results[:api_by_id_failed] << { id: id_str, name: cat.name }
            puts "  ✗ API по ID: продуктов не найдено"
          end
        rescue => e
          results[:api_by_id_failed] << { id: id_str, name: cat.name, error: e.message }
          puts "  ✗ API по ID: ошибка - #{e.message}"
        end
      else
        puts "  - API по ID: пропущено (не числовой ID)"
      end
      
      # Проверка 2: API по названию
      if cat.name.present?
        begin
          # Используем CategoryProductsSearchService для поиска по названию
          search_service = CategoryProductsSearchService.new
          products = search_service.search(cat, offset: 0, limit: 5, strategies: [:api_by_category_name])
          if products.any?
            results[:api_by_name_success] << { id: id_str, name: cat.name, count: products.count }
            puts "  ✓ API по названию: найдено #{products.count} продуктов"
          else
            results[:api_by_name_failed] << { id: id_str, name: cat.name }
            puts "  ✗ API по названию: продуктов не найдено"
          end
        rescue => e
          results[:api_by_name_failed] << { id: id_str, name: cat.name, error: e.message }
          puts "  ✗ API по названию: ошибка - #{e.message}"
        end
      end
      
      # Проверка 3: HTML парсинг
      if cat.url.present?
        begin
          products = CategoryProductsFetcher.fetch(cat.url, offset: 0, limit: 5)
          if products.any?
            results[:html_parsing_success] << { id: id_str, name: cat.name, url: cat.url, count: products.count }
            puts "  ✓ HTML парсинг: найдено #{products.count} продуктов"
          else
            results[:html_parsing_failed] << { id: id_str, name: cat.name, url: cat.url }
            puts "  ✗ HTML парсинг: продуктов не найдено"
          end
        rescue => e
          results[:html_parsing_failed] << { id: id_str, name: cat.name, url: cat.url, error: e.message }
          puts "  ✗ HTML парсинг: ошибка - #{e.message}"
        end
      else
        results[:no_url] << { id: id_str, name: cat.name }
        puts "  - HTML парсинг: пропущено (нет URL)"
      end
      
      # Небольшая задержка между запросами
      sleep(0.5)
    end
    
    puts "\n" + "=" * 80
    puts "РЕЗУЛЬТАТЫ АНАЛИЗА:"
    puts "=" * 80
    puts "\nВсего проверено: #{results[:total_checked]}"
    puts "\n📊 API по ID категории:"
    puts "  ✓ Успешно: #{results[:api_by_id_success].count}"
    puts "  ✗ Не найдено/ошибка: #{results[:api_by_id_failed].count}"
    
    puts "\n📊 API по названию категории:"
    puts "  ✓ Успешно: #{results[:api_by_name_success].count}"
    puts "  ✗ Не найдено/ошибка: #{results[:api_by_name_failed].count}"
    
    puts "\n📊 HTML парсинг:"
    puts "  ✓ Успешно: #{results[:html_parsing_success].count}"
    puts "  ✗ Не найдено/ошибка: #{results[:html_parsing_failed].count}"
    puts "  - Без URL: #{results[:no_url].count}"
    
    if results[:api_by_id_success].any?
      puts "\n✅ Категории, для которых работает API по ID:"
      results[:api_by_id_success].first(10).each do |item|
        puts "  - #{item[:id]} | #{item[:name]} (#{item[:count]} продуктов)"
      end
    end
    
    if results[:api_by_name_success].any?
      puts "\n✅ Категории, для которых работает API по названию:"
      results[:api_by_name_success].first(10).each do |item|
        puts "  - #{item[:id]} | #{item[:name]} (#{item[:count]} продуктов)"
      end
    end
    
    if results[:html_parsing_success].any?
      puts "\n✅ Категории, для которых работает HTML парсинг:"
      results[:html_parsing_success].first(10).each do |item|
        puts "  - #{item[:id]} | #{item[:name]} | #{item[:url]} (#{item[:count]} продуктов)"
      end
    end
    
    puts "\n" + "=" * 80
  end
end

