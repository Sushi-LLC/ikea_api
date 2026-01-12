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
  
  desc "Список категорий с цифровым кодом и информация о сборе продуктов"
  task list_numeric: :environment do
    puts "=" * 80
    puts "Категории с цифровым кодом (ikea_id состоит только из цифр)"
    puts "=" * 80
    
    # Получаем все категории с цифровым кодом
    numeric_categories = Category.with_numeric_id
                                 .select(:ikea_id, :name, :translated_name, :url, :is_popular, :is_important, :is_deleted, :parent_ids)
                                 .order(:ikea_id)
    
    total = numeric_categories.count
    active = numeric_categories.where(is_deleted: [false, nil]).count
    
    puts "\n📊 Статистика:"
    puts "  - Всего категорий с цифровым кодом: #{total}"
    puts "  - Активных: #{active}"
    puts "  - Удаленных: #{total - active}"
    
    # Группируем по наличию продуктов
    categories_with_products = numeric_categories.joins(:products).distinct.count
    categories_without_products = total - categories_with_products
    
    puts "\n📦 Продукты:"
    puts "  - С продуктами: #{categories_with_products}"
    puts "  - Без продуктов: #{categories_without_products}"
    
    # Статистика по URL
    with_url = numeric_categories.where.not(url: [nil, '']).count
    without_url = total - with_url
    
    puts "\n🔗 URL:"
    puts "  - С URL: #{with_url}"
    puts "  - Без URL: #{without_url}"
    
    # Популярные и важные
    popular = numeric_categories.where(is_popular: true).count
    important = numeric_categories.where(is_important: true).count
    
    puts "\n⭐ Особые категории:"
    puts "  - Популярные: #{popular}"
    puts "  - Важные: #{important}"
    
    puts "\n" + "=" * 80
    puts "Список категорий с цифровым кодом (первые 50):"
    puts "=" * 80
    
    numeric_categories.limit(50).each do |cat|
      products_count = cat.products.count
      children_count = cat.children_count
      status = cat.is_deleted? ? "❌ Удалена" : "✅ Активна"
      popular_tag = cat.is_popular? ? "⭐" : ""
      important_tag = cat.is_important? ? "🔝" : ""
      url_tag = cat.url.present? ? "🔗" : ""
      
      puts "\n#{cat.ikea_id} | #{cat.name}"
      puts "  Статус: #{status} #{popular_tag} #{important_tag}"
      puts "  Продуктов: #{products_count} | Дочерних категорий: #{children_count}"
      puts "  URL: #{cat.url || 'нет'} #{url_tag}"
      puts "  Переведенное имя: #{cat.translated_name || 'нет'}"
    end
    
    if total > 50
      puts "\n... и еще #{total - 50} категорий"
    end
    
    puts "\n" + "=" * 80
    puts "Как собираются продукты для категорий с цифровым кодом:"
    puts "=" * 80
    puts <<~DOC
      
      Для категорий с цифровым кодом (ikea_id состоит только из цифр) используется
      сервис CategoryProductsSearchService со следующими стратегиями (в порядке приоритета):
      
      1. HTML парсинг (приоритет 1)
         - Используется, если у категории есть URL
         - Парсит страницу категории IKEA через CategoryProductsFetcher
         - Ищет продукты в JSON-LD, window.__INITIAL_STATE__, data-атрибутах и HTML структуре
      
      2. API по ID категории (приоритет 2)
         - Использует IkeaApiService.search_products_by_category(category_id)
         - Работает только для числовых ID
         - Прямой запрос к API IKEA по ID категории
      
      3. Альтернативный API endpoint (приоритет 3)
         - Альтернативный формат запроса к API IKEA
         - Использует тот же endpoint, но с другими параметрами
      
      4. Поиск через дочерние категории (приоритет 4)
         - Если у категории есть дочерние категории
         - Рекурсивно собирает продукты из дочерних категорий
         - Ограничение: до 10 дочерних категорий первого уровня, до 5 второго уровня
      
      5. API по названию категории (приоритет 5, fallback)
         - Текстовый поиск по первым 3 словам названия категории
         - Используется как последний вариант, если другие не сработали
      
      Оптимальный порядок стратегий определяется методом:
      CategoryProductsSearchService.optimal_strategies_for_category(category)
      
      Пример использования:
        category = Category.find_by(ikea_id: '12345')
        products = CategoryProductsSearchService.search(category, offset: 0, limit: 50)
      
    DOC
    
    puts "\n" + "=" * 80
    puts "Категории без продуктов (первые 20):"
    puts "=" * 80
    
    numeric_without_products = numeric_categories
                                 .left_joins(:products)
                                 .where(products: { id: nil })
                                 .where(is_deleted: [false, nil])
                                 .limit(20)
    
    numeric_without_products.each do |cat|
      strategies = CategoryProductsSearchService.optimal_strategies_for_category(cat)
      url_info = cat.url.present? ? "✓ URL есть" : "✗ URL нет"
      children_info = cat.has_children? ? "✓ Есть дочерние (#{cat.children_count})" : "✗ Нет дочерних"
      
      puts "\n#{cat.ikea_id} | #{cat.name}"
      puts "  #{url_info} | #{children_info}"
      puts "  Рекомендуемые стратегии: #{strategies.join(', ')}"
    end
    
    puts "\n" + "=" * 80
    puts "Анализ завершен"
    puts "=" * 80
  end
  
  desc "Получить список категорий без продуктов (с опцией экспорта и удаления)"
  task :get_empty, [:export_format, :delete] => :environment do |t, args|
    export_format = args[:export_format]&.downcase # csv, json, или nil
    delete_flag = args[:delete]&.downcase == 'true' || args[:delete] == '1'
    
    puts "=" * 80
    puts "Категории без продуктов"
    puts "=" * 80
    
    # Получаем все категории без продуктов (активные)
    empty_categories = Category.left_joins(:products)
                              .where(products: { id: nil })
                              .where(is_deleted: [false, nil])
                              .select(:ikea_id, :name, :translated_name, :url, :is_popular, :is_important, :parent_ids, :created_at, :updated_at)
                              .order(:name)
    
    total = empty_categories.count
    
    puts "\n📊 Статистика:"
    puts "  - Всего категорий без продуктов: #{total}"
    
    if total == 0
      puts "\n✅ Категорий без продуктов не найдено!"
      next
    end
    
    # Группируем по типу ID
    numeric_ids = []
    uuid_ids = []
    other_ids = []
    
    empty_categories.each do |cat|
      id_str = cat.ikea_id.to_s
      
      if id_str.match?(/^\d+$/)
        numeric_ids << cat
      elsif id_str.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
        uuid_ids << cat
      else
        other_ids << cat
      end
    end
    
    puts "\n📋 Распределение по типам ID:"
    puts "  - Числовые ID: #{numeric_ids.count}"
    puts "  - UUID: #{uuid_ids.count}"
    puts "  - Другие форматы: #{other_ids.count}"
    
    # Статистика по URL
    with_url = empty_categories.where.not(url: [nil, '']).count
    without_url = total - with_url
    
    puts "\n🔗 URL:"
    puts "  - С URL: #{with_url}"
    puts "  - Без URL: #{without_url}"
    
    # Популярные и важные
    popular = empty_categories.where(is_popular: true).count
    important = empty_categories.where(is_important: true).count
    
    puts "\n⭐ Особые категории:"
    puts "  - Популярные: #{popular}"
    puts "  - Важные: #{important}"
    
    if popular > 0 || important > 0
      puts "\n⚠️  ВНИМАНИЕ: Среди категорий без продуктов есть популярные или важные!"
    end
    
    # Выводим список (первые 50)
    puts "\n" + "=" * 80
    puts "Список категорий без продуктов (первые 50):"
    puts "=" * 80
    
    empty_categories.limit(50).each do |cat|
      children_count = cat.children_count
      status_tags = []
      status_tags << "⭐" if cat.is_popular?
      status_tags << "🔝" if cat.is_important?
      status_tags << "🔗" if cat.url.present?
      
      puts "\n#{cat.ikea_id} | #{cat.name}"
      puts "  Переведенное имя: #{cat.translated_name || 'нет'}"
      puts "  URL: #{cat.url || 'нет'}"
      puts "  Дочерних категорий: #{children_count}"
      puts "  Теги: #{status_tags.join(' ') || 'нет'}"
      puts "  Создана: #{cat.created_at.strftime('%Y-%m-%d %H:%M')}"
    end
    
    if total > 50
      puts "\n... и еще #{total - 50} категорий"
    end
    
    # Экспорт в файл
    if export_format
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      filename = "categories_without_products_#{timestamp}"
      
      case export_format
      when 'csv'
        require 'csv'
        filename += '.csv'
        filepath = Rails.root.join('tmp', filename)
        
        CSV.open(filepath, 'w', headers: true, write_headers: true) do |csv|
          csv << ['ikea_id', 'name', 'translated_name', 'url', 'is_popular', 'is_important', 'children_count', 'created_at']
          
          empty_categories.find_each do |cat|
            csv << [
              cat.ikea_id,
              cat.name,
              cat.translated_name,
              cat.url,
              cat.is_popular? ? 'Да' : 'Нет',
              cat.is_important? ? 'Да' : 'Нет',
              cat.children_count,
              cat.created_at.strftime('%Y-%m-%d %H:%M:%S')
            ]
          end
        end
        
        puts "\n✅ Экспортировано в CSV: #{filepath}"
        puts "   Всего записей: #{total}"
        
      when 'json'
        filename += '.json'
        filepath = Rails.root.join('tmp', filename)
        
        data = empty_categories.map do |cat|
          {
            ikea_id: cat.ikea_id,
            name: cat.name,
            translated_name: cat.translated_name,
            url: cat.url,
            is_popular: cat.is_popular?,
            is_important: cat.is_important?,
            children_count: cat.children_count,
            created_at: cat.created_at.iso8601,
            updated_at: cat.updated_at.iso8601
          }
        end
        
        File.write(filepath, JSON.pretty_generate(data))
        
        puts "\n✅ Экспортировано в JSON: #{filepath}"
        puts "   Всего записей: #{total}"
        
      else
        puts "\n❌ Неподдерживаемый формат экспорта: #{export_format}"
        puts "   Поддерживаемые форматы: csv, json"
      end
    end
    
    # Удаление (мягкое удаление - is_deleted = true)
    if delete_flag
      puts "\n" + "=" * 80
      puts "⚠️  УДАЛЕНИЕ КАТЕГОРИЙ БЕЗ ПРОДУКТОВ"
      puts "=" * 80
      puts "\nВНИМАНИЕ: Будет выполнено мягкое удаление (is_deleted = true)"
      puts "Всего категорий для удаления: #{total}"
      
      if popular > 0 || important > 0
        puts "\n⚠️  ВНИМАНИЕ: Среди категорий есть популярные или важные!"
        puts "   Популярных: #{popular}"
        puts "   Важных: #{important}"
      end
      
      puts "\nНажмите Enter для подтверждения или Ctrl+C для отмены..."
      STDIN.gets
      
      deleted_count = 0
      skipped_count = 0
      
      empty_categories.find_each do |cat|
        # Пропускаем популярные и важные категории
        if cat.is_popular? || cat.is_important?
          skipped_count += 1
          puts "⏭️  Пропущена (популярная/важная): #{cat.ikea_id} | #{cat.name}"
          next
        end
        
        cat.update(is_deleted: true)
        deleted_count += 1
        
        if deleted_count % 100 == 0
          puts "  Удалено: #{deleted_count}/#{total}"
        end
      end
      
      puts "\n" + "=" * 80
      puts "Результат удаления:"
      puts "  ✅ Удалено: #{deleted_count}"
      puts "  ⏭️  Пропущено (популярные/важные): #{skipped_count}"
      puts "=" * 80
      
      # Очищаем кэш категорий
      Rails.cache.delete_matched("categories_tree_*")
      Rails.cache.delete("categories_product_counts")
      Rails.cache.delete("categories_children_counts")
      Rails.cache.delete("categories_max_updated_at")
      
      puts "\n✅ Кэш категорий очищен"
    end
    
    puts "\n" + "=" * 80
    puts "Завершено"
    puts "=" * 80
    puts "\n💡 Подсказки:"
    puts "  - Экспорт в CSV: rake categories:get_empty[csv]"
    puts "  - Экспорт в JSON: rake categories:get_empty[json]"
    puts "  - Удалить категории: rake categories:get_empty[,true]"
    puts "  - Экспорт и удаление: rake categories:get_empty[csv,true]"
  end
  
  desc "Диагностика причин отсутствия продуктов в категориях"
  task :diagnose_empty, [:limit] => :environment do |t, args|
    limit = (args[:limit] || 10).to_i
    
    puts "=" * 80
    puts "Диагностика причин отсутствия продуктов в категориях"
    puts "=" * 80
    
    # Получаем категории без продуктов
    empty_categories = Category.left_joins(:products)
                              .where(products: { id: nil })
                              .where(is_deleted: [false, nil])
                              .select('categories.ikea_id, categories.name, categories.translated_name, categories.url, categories.is_popular, categories.is_important, categories.parent_ids')
                              .order('categories.name')
                              .limit(limit)
    
    total = empty_categories.count
    
    if total == 0
      puts "\n✅ Категорий без продуктов не найдено!"
      next
    end
    
    puts "\n📊 Анализируем #{total} категорий без продуктов..."
    puts "=" * 80
    
    reasons_stats = {
      no_url: [],
      uuid_id_no_api: [],
      api_failed: [],
      html_parsing_failed: [],
      no_children: [],
      children_without_products: [],
      api_success: [],
      html_success: [],
      children_success: []
    }
    
    empty_categories.each_with_index do |category, index|
      puts "\n[#{index + 1}/#{total}] Анализ: #{category.name} (#{category.ikea_id})"
      puts "-" * 80
      
      reasons = []
      
      # 1. Проверка типа ID
      is_numeric = category.numeric_id?
      is_uuid = category.uuid_id?
      
      puts "  Тип ID: #{is_numeric ? 'Числовой' : (is_uuid ? 'UUID' : 'Другой')}"
      
      # 2. Проверка URL
      has_url = category.url.present?
      puts "  URL: #{has_url ? "✓ Есть (#{category.url[0..50]}...)" : "✗ Нет"}"
      
      if !has_url
        reasons << "Нет URL для HTML парсинга"
        reasons_stats[:no_url] << category
      end
      
      # 3. Проверка дочерних категорий
      children_count = category.children_count
      has_children = children_count > 0
      puts "  Дочерних категорий: #{children_count}"
      
      if !has_children
        reasons << "Нет дочерних категорий"
        reasons_stats[:no_children] << category
      else
        # Проверяем, есть ли продукты в дочерних категориях
        # Используем отдельный запрос, чтобы избежать неоднозначности колонок
        children_ids = category.children.pluck(:ikea_id)
        children_with_products = Category.where(ikea_id: children_ids)
                                         .joins(:products)
                                         .distinct
                                         .count
        puts "  Дочерних с продуктами: #{children_with_products}/#{children_count}"
        
        if children_with_products == 0
          reasons << "Дочерние категории тоже без продуктов"
          reasons_stats[:children_without_products] << category
        else
          reasons_stats[:children_success] << category
          puts "  ✓ Можно получить продукты через дочерние категории"
        end
      end
      
      # 4. Тест API (только для числовых ID)
      if is_numeric
        begin
          puts "  Тестирую API по ID..."
          products = CategoryProductsSearchService.search(
            category,
            offset: 0,
            limit: 5,
            strategies: [:api_by_category_id]
          )
          
          if products.any?
            reasons_stats[:api_success] << category
            puts "  ✓ API работает! Найдено продуктов: #{products.length}"
          else
            reasons << "API не вернул продукты"
            reasons_stats[:api_failed] << category
            puts "  ✗ API не вернул продукты"
          end
        rescue => e
          reasons << "API ошибка: #{e.message[0..50]}"
          reasons_stats[:api_failed] << category
          puts "  ✗ API ошибка: #{e.message[0..100]}"
        end
      elsif is_uuid
        reasons << "UUID ID - API не поддерживается"
        reasons_stats[:uuid_id_no_api] << category
        puts "  ⚠ UUID ID - API по ID не работает"
      end
      
      # 5. Тест HTML парсинга (если есть URL)
      if has_url
        begin
          puts "  Тестирую HTML парсинг..."
          products = CategoryProductsSearchService.search(
            category,
            offset: 0,
            limit: 5,
            strategies: [:html_parsing]
          )
          
          if products.any?
            reasons_stats[:html_success] << category
            puts "  ✓ HTML парсинг работает! Найдено продуктов: #{products.length}"
          else
            reasons << "HTML парсинг не нашел продукты"
            reasons_stats[:html_parsing_failed] << category
            puts "  ✗ HTML парсинг не нашел продукты"
          end
        rescue => e
          reasons << "HTML парсинг ошибка: #{e.message[0..50]}"
          reasons_stats[:html_parsing_failed] << category
          puts "  ✗ HTML парсинг ошибка: #{e.message[0..100]}"
        end
      end
      
      # Выводим итоговые причины
      if reasons.any?
        puts "\n  🔍 Причины отсутствия продуктов:"
        reasons.each { |r| puts "    - #{r}" }
      else
        puts "\n  ⚠️  Не удалось определить причину (возможно, категория действительно пустая)"
      end
      
      # Небольшая задержка между запросами
      sleep(0.3) if index < total - 1
    end
    
    # Итоговая статистика
    puts "\n" + "=" * 80
    puts "ИТОГОВАЯ СТАТИСТИКА ПРИЧИН:"
    puts "=" * 80
    
    puts "\n❌ Проблемы:"
    puts "  - Нет URL: #{reasons_stats[:no_url].count}"
    puts "  - UUID ID (API не работает): #{reasons_stats[:uuid_id_no_api].count}"
    puts "  - API не вернул продукты: #{reasons_stats[:api_failed].count}"
    puts "  - HTML парсинг не нашел продукты: #{reasons_stats[:html_parsing_failed].count}"
    puts "  - Нет дочерних категорий: #{reasons_stats[:no_children].count}"
    puts "  - Дочерние категории тоже без продуктов: #{reasons_stats[:children_without_products].count}"
    
    puts "\n✅ Рабочие методы получения продуктов:"
    puts "  - API работает: #{reasons_stats[:api_success].count}"
    puts "  - HTML парсинг работает: #{reasons_stats[:html_success].count}"
    puts "  - Можно получить через дочерние: #{reasons_stats[:children_success].count}"
    
    # Рекомендации
    puts "\n" + "=" * 80
    puts "РЕКОМЕНДАЦИИ:"
    puts "=" * 80
    
    if reasons_stats[:api_success].any?
      puts "\n✅ Для #{reasons_stats[:api_success].count} категорий API работает - можно запустить парсинг:"
      puts "   ParseProductsJob.perform_async(category_id: 'ID')"
    end
    
    if reasons_stats[:html_success].any?
      puts "\n✅ Для #{reasons_stats[:html_success].count} категорий HTML парсинг работает - можно запустить парсинг"
    end
    
    if reasons_stats[:children_success].any?
      puts "\n✅ Для #{reasons_stats[:children_success].count} категорий можно получить продукты через дочерние категории"
    end
    
    if reasons_stats[:no_url].any?
      puts "\n⚠️  Для #{reasons_stats[:no_url].count} категорий нет URL - нужно добавить URL для HTML парсинга"
    end
    
    if reasons_stats[:uuid_id_no_api].any?
      puts "\n⚠️  Для #{reasons_stats[:uuid_id_no_api].count} категорий с UUID ID API не работает - нужен HTML парсинг или поиск через дочерние"
    end
    
    puts "\n" + "=" * 80
    puts "Диагностика завершена"
    puts "=" * 80
  end
  
  desc "Исправить дочерние категории без продуктов - получить продукты любыми средствами"
  task :fix_children_products, [:limit, :force] => :environment do |t, args|
    limit = (args[:limit] || 50).to_i
    force = args[:force]&.downcase == 'true' || args[:force] == '1'
    
    puts "=" * 80
    puts "Исправление дочерних категорий без продуктов"
    puts "=" * 80
    
    # Находим все категории, у которых есть дочерние категории
    categories_with_children = Category.where(is_deleted: [false, nil])
                                      .select('categories.ikea_id, categories.name, categories.parent_ids')
                                      .to_a
                                      .select { |c| c.children_count > 0 }
    
    puts "\n📊 Найдено категорий с дочерними: #{categories_with_children.count}"
    
    # Находим дочерние категории без продуктов
    empty_children = []
    
    categories_with_children.each do |parent|
      children_ids = parent.children.pluck(:ikea_id)
      children_without_products = Category.where(ikea_id: children_ids)
                                          .left_joins(:products)
                                          .where(products: { id: nil })
                                          .where(is_deleted: [false, nil])
                                          .select('categories.ikea_id, categories.name, categories.translated_name, categories.url, categories.is_popular, categories.is_important, categories.parent_ids')
      
      children_without_products.each do |child|
        empty_children << {
          parent: parent,
          child: child
        }
      end
    end
    
    total_empty = empty_children.count
    puts "📦 Найдено дочерних категорий без продуктов: #{total_empty}"
    
    if total_empty == 0
      puts "\n✅ Все дочерние категории имеют продукты!"
      next
    end
    
    # Ограничиваем количество для обработки
    to_process = empty_children.first(limit)
    puts "\n🔄 Обрабатываем первые #{to_process.count} категорий..."
    puts "=" * 80
    
    stats = {
      processed: 0,
      success: 0,
      failed: 0,
      products_found: 0,
      products_saved: 0
    }
    
    to_process.each_with_index do |item, index|
      parent = item[:parent]
      child = item[:child]
      
      puts "\n[#{index + 1}/#{to_process.count}] Обработка: #{child.name} (#{child.ikea_id})"
      puts "  Родитель: #{parent.name} (#{parent.ikea_id})"
      puts "-" * 80
      
      stats[:processed] += 1
      
      # Диагностика категории
      puts "  Диагностика:"
      puts "    - URL: #{child.url.present? ? "✓ #{child.url[0..60]}..." : "✗ Нет URL"}"
      puts "    - Дочерних категорий: #{child.children_count}"
      puts "    - Тип ID: #{child.numeric_id? ? 'Числовой' : (child.uuid_id? ? 'UUID' : 'Другой')}"
      
      # Определяем оптимальные стратегии для получения продуктов
      strategies = CategoryProductsSearchService.optimal_strategies_for_category(child)
      
      # Для UUID категорий добавляем дополнительные стратегии
      if child.uuid_id? || child.ikea_id.to_s.include?('/')
        # Добавляем все доступные стратегии для UUID категорий
        strategies = [:html_parsing, :children_categories, :api_by_category_name, :html_with_js_rendering]
        strategies.uniq!
      end
      
      puts "  Стратегии: #{strategies.join(', ')}"
      
      products_found = []
      
      # Пробуем все стратегии по очереди
      strategies.each do |strategy|
        begin
          puts "  Пробую стратегию: #{strategy}..."
          
          products = CategoryProductsSearchService.search(
            child,
            offset: 0,
            limit: 100, # Берем больше продуктов для дочерних категорий
            strategies: [strategy]
          )
          
          if products.any?
            products_found = products
            puts "  ✓ Стратегия #{strategy} успешна! Найдено продуктов: #{products.length}"
            break
          else
            puts "  ✗ Стратегия #{strategy} не вернула продукты"
          end
        rescue => e
          puts "  ✗ Стратегия #{strategy} ошибка: #{e.message[0..100]}"
          next
        end
      end
      
      # Если не нашли через стандартные стратегии, пробуем альтернативные методы
      if products_found.empty?
        puts "  🔍 Пробую альтернативные методы..."
        
        # Метод 0: Для UUID категорий с фильтрами в URL - пробуем получить через родительскую категорию
        if (child.uuid_id? || child.ikea_id.to_s.include?('/')) && child.url.present? && child.url.include?('filters=')
          begin
            puts "    - Попытка получить продукты через родительскую категорию..."
            parent = item[:parent]
            
            # Если родитель имеет числовой ID, пробуем получить все продукты родителя
            if parent.numeric_id?
              puts "    - Родитель имеет числовой ID (#{parent.ikea_id}), получаю продукты..."
              parent_products = CategoryProductsSearchService.search(
                parent,
                offset: 0,
                limit: 200,
                strategies: [:api_by_category_id]
              )
              
              if parent_products.any?
                puts "    ✓ Найдено #{parent_products.length} продуктов в родительской категории"
                # Берем первые продукты из родительской категории для дочерней
                products_found = parent_products.first(50)
                puts "    ✓ Использую #{products_found.length} продуктов для дочерней категории"
              end
            end
          rescue => e
            puts "    ✗ Ошибка получения через родителя: #{e.message[0..100]}"
          end
        end
        
        # Метод 1: Поиск через дочерние категории (если есть)
        if products_found.empty? && child.has_children?
          begin
            puts "    - Поиск через дочерние категории..."
            children_ids = child.children.pluck(:ikea_id)
            children_with_products = Category.where(ikea_id: children_ids)
                                            .joins(:products)
                                            .select('categories.ikea_id')
                                            .distinct
                                            .pluck(:ikea_id)
            
            if children_with_products.any?
              puts "    ✓ Найдено #{children_with_products.length} дочерних категорий с продуктами"
              # Получаем продукты из дочерних категорий
              child_products = Product.where(category_id: children_with_products).limit(50)
              
              if child_products.any?
                # Конвертируем существующие продукты в формат для сохранения
                products_found = child_products.map do |p|
                  {
                    'id' => p.sku,
                    'sku' => p.sku,
                    'itemNo' => p.item_no,
                    'itemNoGlobal' => p.item_no,
                    'name' => p.name,
                    'typeName' => p.name,
                    'pipUrl' => p.url,
                    'url' => p.url,
                    'salesPrice' => p.price ? { 'numeral' => p.price } : nil,
                    'price' => p.price,
                    'imageUrl' => p.images&.first,
                    'images' => p.images || []
                  }
                end
                puts "    ✓ Найдено #{products_found.length} продуктов через дочерние категории"
              end
            end
          rescue => e
            puts "    ✗ Ошибка поиска через дочерние: #{e.message[0..100]}"
          end
        end
        
        # Метод 2: Поиск продуктов по названию категории в базе данных
        if products_found.empty? && child.name.present?
          begin
            puts "    - Поиск продуктов по названию в БД..."
            # Ищем продукты, которые могут относиться к этой категории
            # (например, по ключевым словам в названии)
            search_terms = child.name.split(' ').first(3)
            found_products = Product.where("name ILIKE ?", "%#{search_terms.first}%")
                                  .where(category_id: nil)
                                  .limit(20)
            
            if found_products.any?
              products_found = found_products.map do |p|
                {
                  'id' => p.sku,
                  'sku' => p.sku,
                  'itemNo' => p.item_no,
                  'itemNoGlobal' => p.item_no,
                  'name' => p.name,
                  'typeName' => p.name,
                  'pipUrl' => p.url,
                  'url' => p.url,
                  'salesPrice' => p.price ? { 'numeral' => p.price } : nil,
                  'price' => p.price,
                  'imageUrl' => p.images&.first,
                  'images' => p.images || []
                }
              end
              puts "    ✓ Найдено #{products_found.length} продуктов по названию в БД"
            end
          rescue => e
            puts "    ✗ Ошибка поиска в БД: #{e.message[0..100]}"
          end
        end
      end
      
      # Если нашли продукты, сохраняем их
      if products_found.any?
        stats[:products_found] += products_found.length
        
        puts "  💾 Сохраняю #{products_found.length} продуктов..."
        
        saved_count = 0
        skipped_count = 0
        
        products_found.each do |product_data|
          begin
            # Используем ту же логику, что и в ParseProductsJob
            sku = product_data['id'] || product_data[:id] || product_data['sku'] || product_data[:sku]
            next unless sku.present?
            
            # Проверяем, существует ли продукт
            existing_product = Product.find_by(sku: sku)
            
            if existing_product
              # Если продукт уже существует, добавляем связь с категорией (many-to-many)
              unless existing_product.categories.exists?(ikea_id: child.ikea_id)
                CategoryProduct.find_or_create_by(
                  product: existing_product,
                  category_id: child.ikea_id
                )
                saved_count += 1
                puts "    ✓ Добавлена связь: #{sku} -> категория #{child.ikea_id}"
              else
                skipped_count += 1
              end
            else
              # Создаем новый продукт
              # Нормализуем данные
              normalized = {}
              product_data.each { |k, v| normalized[k.to_s] = v }
              product_data = normalized
              
              # Извлекаем данные
              pip_url = product_data['pipUrl'] || product_data['url'] || ''
              url = pip_url.start_with?('http') ? pip_url : "https://www.ikea.com#{pip_url}"
              
              item_no = product_data['itemNoGlobal'] || 
                       product_data['itemNo'] || 
                       product_data['item_no']
              
              name = product_data['typeName'] || product_data['name'] || 'Unknown'
              
              images = if product_data.dig('gprDescription', 'variants')
                        product_data.dig('gprDescription', 'variants')&.map { |v| v['imageUrl'] }&.compact || []
                      elsif product_data['imageUrl']
                        [product_data['imageUrl']].compact
                      elsif product_data['images']
                        Array(product_data['images'])
                      else
                        []
                      end
              
              price = product_data.dig('salesPrice', 'numeral') || 
                      product_data.dig('price', 'numeral') ||
                      product_data['price']
              
              is_bestseller = product_data['isBestseller'] || false
              is_popular = product_data['isPopular'] || false
              
              # Создаем продукт (без category_id, связь добавим через CategoryProduct)
              new_product = Product.create!(
                sku: sku,
                item_no: item_no,
                url: url,
                name: name,
                price: price,
                images: images,
                is_bestseller: is_bestseller,
                is_popular: is_popular
              )
              
              # Добавляем связь с категорией через промежуточную таблицу
              CategoryProduct.create!(
                product: new_product,
                category_id: child.ikea_id
              )
              
              saved_count += 1
              puts "    ✓ Создан продукт: #{sku} (#{name[0..50]})"
            end
          rescue => e
            puts "    ✗ Ошибка сохранения продукта: #{e.message[0..100]}"
            stats[:failed] += 1
          end
        end
        
        stats[:products_saved] += saved_count
        stats[:success] += 1
        
        puts "  ✅ Сохранено: #{saved_count}, пропущено: #{skipped_count}"
      else
        puts "  ❌ Не удалось найти продукты для категории #{child.ikea_id}"
        stats[:failed] += 1
      end
      
      # Небольшая задержка между категориями
      sleep(0.5) if index < to_process.count - 1
    end
    
    # Итоговая статистика
    puts "\n" + "=" * 80
    puts "ИТОГОВАЯ СТАТИСТИКА:"
    puts "=" * 80
    puts "\n📊 Обработано категорий: #{stats[:processed]}"
    puts "  ✅ Успешно: #{stats[:success]}"
    puts "  ❌ Не удалось: #{stats[:failed]}"
    puts "\n📦 Продукты:"
    puts "  - Найдено: #{stats[:products_found]}"
    puts "  - Сохранено: #{stats[:products_saved]}"
    
    if stats[:success] > 0
      puts "\n✅ Успешно обработано #{stats[:success]} дочерних категорий!"
    end
    
    if stats[:failed] > 0
      puts "\n⚠️  Не удалось получить продукты для #{stats[:failed]} категорий"
      puts "   Попробуйте запустить задачу снова или увеличьте лимит"
    end
    
    puts "\n" + "=" * 80
    puts "Завершено"
    puts "=" * 80
    puts "\n💡 Подсказки:"
    puts "  - Обработать больше категорий: rake categories:fix_children_products[100]"
    puts "  - Принудительно обновить category_id: rake categories:fix_children_products[50,true]"
  end
  
  desc "Получить продукты для конкретной категории (для диагностики)"
  task :get_products, [:category_id] => :environment do |t, args|
    category_id = args[:category_id]
    
    unless category_id
      puts "❌ Ошибка: Укажите ID категории"
      puts "   Использование: rake categories:get_products[18694]"
      next
    end
    
    puts "=" * 80
    puts "Получение продуктов для категории #{category_id}"
    puts "=" * 80
    
    category = Category.find_by(ikea_id: category_id)
    
    unless category
      puts "\n❌ Категория с ID #{category_id} не найдена в базе данных"
      next
    end
    
    puts "\n📋 Информация о категории:"
    puts "  - ID: #{category.ikea_id}"
    puts "  - Название: #{category.name}"
    puts "  - Переведенное имя: #{category.translated_name || 'нет'}"
    puts "  - URL: #{category.url || 'нет'}"
    puts "  - Тип ID: #{category.numeric_id? ? 'Числовой' : (category.uuid_id? ? 'UUID' : 'Другой')}"
    puts "  - Дочерних категорий: #{category.children_count}"
    puts "  - Продуктов в БД: #{category.products.count}"
    
    # Проверяем, есть ли продукты в БД
    existing_products = category.products.count
    if existing_products > 0
      puts "\n✅ В базе данных уже есть #{existing_products} продуктов"
      puts "   Первые 5 продуктов:"
      category.products.limit(5).each do |p|
        puts "     - #{p.sku}: #{p.name}"
      end
    else
      puts "\n⚠️  В базе данных нет продуктов для этой категории"
    end
    
    # Пробуем получить продукты через API
    puts "\n" + "=" * 80
    puts "Попытка получить продукты через API..."
    puts "=" * 80
    
    if category.numeric_id?
      begin
        puts "\n1. Пробую API по ID категории..."
        products = IkeaApiService.search_products_by_category(category.ikea_id, offset: 0, limit: 50)
        
        if products.any?
          puts "   ✅ API вернул #{products.length} продуктов!"
          puts "\n   Первые 5 продуктов из API:"
          products.first(5).each do |p|
            sku = p['id'] || p[:id] || p['sku'] || p[:sku] || 'N/A'
            name = p['name'] || p[:name] || p['typeName'] || p[:typeName] || 'N/A'
            puts "     - #{sku}: #{name[0..50]}"
          end
          
          # Сохраняем продукты
          puts "\n" + "=" * 80
          puts "Сохранение продуктов в базу данных..."
          puts "=" * 80
          
          saved_count = 0
          skipped_count = 0
          error_count = 0
          
          products.each do |product_data|
            begin
              sku = product_data['id'] || product_data[:id] || product_data['sku'] || product_data[:sku]
              next unless sku.present?
              
              existing = Product.find_by(sku: sku)
              
              if existing
                # Добавляем связь с категорией (many-to-many)
                unless existing.categories.exists?(ikea_id: category.ikea_id)
                  CategoryProduct.find_or_create_by(
                    product: existing,
                    category_id: category.ikea_id
                  )
                  saved_count += 1
                  puts "   ✓ Добавлена связь: #{sku} -> категория #{category.ikea_id}"
                else
                  skipped_count += 1
                end
              else
                # Нормализуем данные
                normalized = {}
                product_data.each { |k, v| normalized[k.to_s] = v }
                product_data = normalized
                
                # Извлекаем данные
                pip_url = product_data['pipUrl'] || product_data['url'] || ''
                url = pip_url.start_with?('http') ? pip_url : "https://www.ikea.com#{pip_url}"
                
                item_no = product_data['itemNoGlobal'] || 
                         product_data['itemNo'] || 
                         product_data['item_no']
                
                name = product_data['typeName'] || product_data['name'] || 'Unknown'
                
                images = if product_data.dig('gprDescription', 'variants')
                          product_data.dig('gprDescription', 'variants')&.map { |v| v['imageUrl'] }&.compact || []
                        elsif product_data['imageUrl']
                          [product_data['imageUrl']].compact
                        elsif product_data['images']
                          Array(product_data['images'])
                        else
                          []
                        end
                
                price = product_data.dig('salesPrice', 'numeral') || 
                        product_data.dig('price', 'numeral') ||
                        product_data['price']
                
                is_bestseller = product_data['isBestseller'] || false
                is_popular = product_data['isPopular'] || false
                
                new_product = Product.create!(
                  sku: sku,
                  item_no: item_no,
                  url: url,
                  name: name,
                  price: price,
                  images: images,
                  is_bestseller: is_bestseller,
                  is_popular: is_popular
                )
                
                # Добавляем связь с категорией через промежуточную таблицу
                CategoryProduct.create!(
                  product: new_product,
                  category_id: category.ikea_id
                )
                
                saved_count += 1
                puts "   ✓ Создан: #{sku} (#{name[0..50]})"
              end
            rescue => e
              error_count += 1
              puts "   ✗ Ошибка сохранения #{sku}: #{e.message[0..100]}"
            end
          end
          
          puts "\n" + "=" * 80
          puts "Результат сохранения:"
          puts "  ✅ Сохранено/обновлено: #{saved_count}"
          puts "  ⏭️  Пропущено: #{skipped_count}"
          puts "  ❌ Ошибок: #{error_count}"
          puts "=" * 80
        else
          puts "   ❌ API не вернул продукты"
        end
      rescue => e
        puts "   ❌ Ошибка API: #{e.message}"
        puts "   #{e.backtrace.first(3).join("\n   ")}"
      end
    else
      puts "\n⚠️  Категория не имеет числового ID - API по ID не работает"
      puts "   Попробуйте другие методы получения продуктов"
    end
    
    # Пробуем HTML парсинг
    if category.url.present?
      puts "\n" + "=" * 80
      puts "Попытка получить продукты через HTML парсинг..."
      puts "=" * 80
      
      begin
        products = CategoryProductsFetcher.fetch(category.url, offset: 0, limit: 50)
        
        if products.any?
          puts "   ✅ HTML парсинг нашел #{products.length} продуктов!"
          puts "\n   Первые 5 продуктов:"
          products.first(5).each do |p|
            sku = p['id'] || p[:id] || p['sku'] || p[:sku] || 'N/A'
            name = p['name'] || p[:name] || p['typeName'] || p[:typeName] || 'N/A'
            puts "     - #{sku}: #{name[0..50]}"
          end
        else
          puts "   ❌ HTML парсинг не нашел продукты"
        end
      rescue => e
        puts "   ❌ Ошибка HTML парсинга: #{e.message}"
      end
    else
      puts "\n⚠️  У категории нет URL для HTML парсинга"
    end
    
    puts "\n" + "=" * 80
    puts "Завершено"
    puts "=" * 80
  end
  
  desc "Получить продукты для всех категорий без продуктов"
  task :get_products_all, [:limit, :skip_numeric, :skip_uuid] => :environment do |t, args|
    limit = (args[:limit] || 1000).to_i
    skip_numeric = args[:skip_numeric]&.downcase == 'true' || args[:skip_numeric] == '1'
    skip_uuid = args[:skip_uuid]&.downcase == 'true' || args[:skip_uuid] == '1'
    
    puts "=" * 80
    puts "Получение продуктов для всех категорий без продуктов"
    puts "=" * 80
    
    # Находим все категории без продуктов
    empty_categories = Category.left_joins(:products)
                              .where(products: { id: nil })
                              .where(is_deleted: [false, nil])
                              .select('categories.ikea_id, categories.name, categories.translated_name, categories.url, categories.parent_ids')
                              .order('categories.name')
                              .limit(limit)
    
    total = empty_categories.count
    
    if total == 0
      puts "\n✅ Все категории имеют продукты!"
      next
    end
    
    puts "\n📊 Найдено категорий без продуктов: #{total}"
    puts "   Лимит обработки: #{limit}"
    puts "   Пропускать числовые ID: #{skip_numeric ? 'Да' : 'Нет'}"
    puts "   Пропускать UUID ID: #{skip_uuid ? 'Да' : 'Нет'}"
    puts "=" * 80
    
    stats = {
      processed: 0,
      success: 0,
      failed: 0,
      skipped: 0,
      products_found: 0,
      products_created: 0,      # Новые продукты (созданные)
      products_updated: 0,      # Существующие продукты (обновлен category_id)
      products_reassigned: 0,   # Продукты, перепривязанные из другой категории
      products_skipped: 0,      # Продукты, которые уже были в этой категории
      numeric_success: 0,
      uuid_success: 0,
      other_success: 0
    }
    
    empty_categories.each_with_index do |category, index|
      # Пропускаем в зависимости от типа ID
      if skip_numeric && category.numeric_id?
        stats[:skipped] += 1
        next
      end
      
      if skip_uuid && (category.uuid_id? || category.ikea_id.to_s.include?('/'))
        stats[:skipped] += 1
        next
      end
      
      puts "\n[#{index + 1}/#{total}] Обработка: #{category.name} (#{category.ikea_id})"
      puts "-" * 80
      
      stats[:processed] += 1
      
      category_type = if category.numeric_id?
                        'Числовой'
                      elsif category.uuid_id?
                        'UUID'
                      else
                        'Другой'
                      end
      puts "  Тип ID: #{category_type}"
      puts "  URL: #{category.url.present? ? "✓ #{category.url[0..60]}..." : "✗ Нет URL"}"
      
      products_found = []
      
      # Для числовых ID используем API (приоритет 1, как в get_products)
      if category.numeric_id?
        begin
          puts "  1. Пробую API по ID категории..."
          products = IkeaApiService.search_products_by_category(category.ikea_id, offset: 0, limit: 100)
          
          if products.any?
            products_found = products
            puts "     ✅ API вернул #{products.length} продуктов!"
          else
            puts "     ✗ API не вернул продукты"
          end
        rescue => e
          puts "     ✗ Ошибка API: #{e.message[0..100]}"
        end
      end
      
      # Если не нашли через API, пробуем HTML парсинг (для категорий с URL)
      if products_found.empty? && category.url.present?
        begin
          puts "  2. Пробую HTML парсинг..."
          html_products = CategoryProductsFetcher.fetch(category.url, offset: 0, limit: 100)
          
          if html_products.any?
            products_found = html_products
            puts "     ✅ HTML парсинг нашел #{html_products.length} продуктов!"
          else
            puts "     ✗ HTML парсинг не нашел продукты"
          end
        rescue => e
          puts "     ✗ Ошибка HTML парсинга: #{e.message[0..100]}"
        end
      end
      
      # Если все еще не нашли, пробуем другие стратегии
      if products_found.empty?
        strategies = CategoryProductsSearchService.optimal_strategies_for_category(category)
        
        strategy_index = 3
        strategies.each do |strategy|
          begin
            puts "  #{strategy_index}. Пробую стратегию #{strategy}..."
            products = CategoryProductsSearchService.search(
              category,
              offset: 0,
              limit: 100,
              strategies: [strategy]
            )
            
            if products.any?
              products_found = products
              puts "     ✅ Стратегия #{strategy} вернула #{products.length} продуктов!"
              break
            else
              puts "     ✗ Стратегия #{strategy} не вернула продукты"
            end
          rescue => e
            puts "     ✗ Стратегия #{strategy} ошибка: #{e.message[0..100]}"
          end
          strategy_index += 1
        end
      end
      
      # Сохраняем продукты (используем ту же логику, что и в get_products)
      if products_found.any?
        stats[:products_found] += products_found.length
        
        created_count = 0
        updated_count = 0
        reassigned_count = 0
        skipped_count = 0
        error_count = 0
        
        products_found.each do |product_data|
          begin
            sku = product_data['id'] || product_data[:id] || product_data['sku'] || product_data[:sku]
            next unless sku.present?
            
            existing = Product.find_by(sku: sku)
            
            if existing
              # Продукт уже существует - проверяем, есть ли уже связь с этой категорией
              if existing.categories.exists?(ikea_id: category.ikea_id)
                # Продукт уже связан с этой категорией - пропускаем
                skipped_count += 1
              else
                # Добавляем связь с категорией (many-to-many)
                CategoryProduct.find_or_create_by(
                  product: existing,
                  category_id: category.ikea_id
                )
                updated_count += 1
                
                # Если у продукта была старая связь через category_id, сохраняем её тоже
                if existing.category_id.present? && existing.category_id != category.ikea_id
                  CategoryProduct.find_or_create_by(
                    product: existing,
                    category_id: existing.category_id
                  )
                  reassigned_count += 1
                end
              end
            else
              # Нормализуем данные
              normalized = {}
              product_data.each { |k, v| normalized[k.to_s] = v }
              product_data = normalized
              
              # Извлекаем данные
              pip_url = product_data['pipUrl'] || product_data['url'] || ''
              url = pip_url.start_with?('http') ? pip_url : "https://www.ikea.com#{pip_url}"
              
              item_no = product_data['itemNoGlobal'] || 
                       product_data['itemNo'] || 
                       product_data['item_no']
              
              name = product_data['typeName'] || product_data['name'] || 'Unknown'
              
              images = if product_data.dig('gprDescription', 'variants')
                        product_data.dig('gprDescription', 'variants')&.map { |v| v['imageUrl'] }&.compact || []
                      elsif product_data['imageUrl']
                        [product_data['imageUrl']].compact
                      elsif product_data['images']
                        Array(product_data['images'])
                      else
                        []
                      end
              
              price = product_data.dig('salesPrice', 'numeral') || 
                      product_data.dig('price', 'numeral') ||
                      product_data['price']
              
              is_bestseller = product_data['isBestseller'] || false
              is_popular = product_data['isPopular'] || false
              
              # Создаем новый продукт (без category_id, связь добавим через CategoryProduct)
              new_product = Product.create!(
                sku: sku,
                item_no: item_no,
                url: url,
                name: name,
                price: price,
                images: images,
                is_bestseller: is_bestseller,
                is_popular: is_popular
              )
              
              # Добавляем связь с категорией через промежуточную таблицу
              CategoryProduct.create!(
                product: new_product,
                category_id: category.ikea_id
              )
              
              created_count += 1
            end
          rescue => e
            error_count += 1
            puts "    ✗ Ошибка сохранения #{sku}: #{e.message[0..100]}"
          end
        end
        
        # Обновляем общую статистику
        stats[:products_created] += created_count
        stats[:products_updated] += updated_count
        stats[:products_reassigned] += reassigned_count
        stats[:products_skipped] += skipped_count
        
        stats[:success] += 1
        
        total_changed = created_count + updated_count
        puts "  ✅ Создано: #{created_count} | Добавлено связей: #{updated_count} | Пропущено: #{skipped_count} | Ошибок: #{error_count}"
        
        # Обновляем счетчики по типам (если были изменения)
        if total_changed > 0
          case category_type
          when 'Числовой'
            stats[:numeric_success] += 1
          when 'UUID'
            stats[:uuid_success] += 1
          else
            stats[:other_success] += 1
          end
        end
      else
        puts "  ❌ Не удалось найти продукты"
        stats[:failed] += 1
      end
      
      # Небольшая задержка между категориями (чтобы не нагружать API)
      sleep(0.2) if index < total - 1
      
      # Показываем прогресс каждые 10 категорий
      if (index + 1) % 10 == 0
        puts "\n📊 Прогресс: #{index + 1}/#{total} | Успешно: #{stats[:success]} | Не удалось: #{stats[:failed]} | Пропущено: #{stats[:skipped]}"
        puts "   Продукты: создано: #{stats[:products_created]} | добавлено связей: #{stats[:products_updated]}"
      end
    end
    
    # Итоговая статистика
    puts "\n" + "=" * 80
    puts "ИТОГОВАЯ СТАТИСТИКА:"
    puts "=" * 80
    puts "\n📊 Обработано категорий: #{stats[:processed]}"
    puts "  ✅ Успешно: #{stats[:success]}"
    puts "  ❌ Не удалось: #{stats[:failed]}"
    puts "  ⏭️  Пропущено (фильтры): #{stats[:skipped]}"
    
    puts "\n📦 Продукты:"
    puts "  - Найдено: #{stats[:products_found]}"
    puts "  - Создано (новых): #{stats[:products_created]} ⭐"
    puts "  - Добавлено связей с категориями: #{stats[:products_updated]}"
    puts "  - Пропущено (уже связан с этой категорией): #{stats[:products_skipped]}"
    puts ""
    puts "  ✅ ВАЖНО: Теперь продукт может быть связан с НЕСКОЛЬКИМИ категориями одновременно!"
    puts "      Связи добавляются через промежуточную таблицу category_products."
    puts "      Продукт не 'переезжает' из одной категории в другую, а добавляется в новую категорию."
    
    puts "\n📊 По типам ID:"
    puts "  - Числовые ID (успешно): #{stats[:numeric_success]}"
    puts "  - UUID ID (успешно): #{stats[:uuid_success]}"
    puts "  - Другие (успешно): #{stats[:other_success]}"
    
    if stats[:success] > 0
      puts "\n✅ Успешно обработано #{stats[:success]} категорий!"
      puts "   Создано новых продуктов: #{stats[:products_created]} ⭐"
      puts "   Добавлено связей продукт-категория: #{stats[:products_updated]}"
      puts ""
      if stats[:products_created] > 0
        puts "   💡 Общее количество продуктов в БД увеличилось на #{stats[:products_created]}"
      end
      if stats[:products_updated] > 0
        puts "   💡 Добавлено #{stats[:products_updated]} связей между продуктами и категориями"
        puts "      (продукты теперь могут принадлежать нескольким категориям одновременно)"
      end
    end
    
    if stats[:failed] > 0
      puts "\n⚠️  Не удалось получить продукты для #{stats[:failed]} категорий"
      puts "   Попробуйте запустить задачу снова или увеличьте лимит"
    end
    
    puts "\n" + "=" * 80
    puts "Завершено"
    puts "=" * 80
    puts "\n💡 Подсказки:"
    puts "  - Обработать больше категорий: rake categories:get_products_all[500]"
    puts "  - Пропустить числовые ID: rake categories:get_products_all[100,true]"
    puts "  - Пропустить UUID ID: rake categories:get_products_all[100,,true]"
    puts "  - Обработать только числовые: rake categories:get_products_all[1000,,true]"
  end
  
  desc "Анализ: почему общее количество продуктов не увеличивается при добавлении в категории"
  task :analyze_products_growth => :environment do
    puts "=" * 80
    puts "АНАЛИЗ: Почему общее количество продуктов не увеличивается?"
    puts "=" * 80
    
    total_products = Product.count
    products_with_category = Product.where.not(category_id: nil).count
    products_without_category = Product.where(category_id: nil).count
    
    puts "\n📊 Общая статистика продуктов:"
    puts "  - Всего продуктов в БД: #{total_products}"
    puts "  - С привязкой к категории: #{products_with_category}"
    puts "  - Без привязки к категории: #{products_without_category}"
    
    # Проверяем структуру связи
    puts "\n📋 Структура связи Product-Category:"
    puts "  - Модель Product: belongs_to :category (один продукт = одна категория)"
    puts "  - Модель Category: has_many :products (одна категория = много продуктов)"
    puts "  - Поле в БД: products.category_id (string)"
    puts ""
    puts "  ⚠️  ВАЖНО: Продукт может быть привязан только к ОДНОЙ категории!"
    puts "      Это связь один-к-одному, а не многие-ко-многим."
    
    # Анализ: сколько продуктов в категориях без продуктов
    empty_categories = Category.left_joins(:products)
                              .where(products: { id: nil })
                              .where(is_deleted: [false, nil])
                              .count
    
    puts "\n📦 Категории без продуктов:"
    puts "  - Активных категорий без продуктов: #{empty_categories}"
    
    # Проверяем, сколько уникальных SKU есть в БД
    unique_skus = Product.select(:sku).distinct.count
    
    puts "\n🔍 Анализ уникальности:"
    puts "  - Всего продуктов: #{total_products}"
    puts "  - Уникальных SKU: #{unique_skus}"
    
    if total_products != unique_skus
      duplicates = total_products - unique_skus
      puts "  ⚠️  Обнаружены дубликаты: #{duplicates} продуктов с одинаковыми SKU"
    else
      puts "  ✅ Все продукты имеют уникальные SKU"
    end
    
    # Проверяем распределение продуктов по категориям
    puts "\n📊 Распределение продуктов по категориям:"
    
    category_products = Product.select(:category_id)
                                .where.not(category_id: nil)
                                .group(:category_id)
                                .count
                                .sort_by { |_k, v| -v }
    
    top_categories = category_products.first(10)
    
    if top_categories.any?
      puts "  Топ-10 категорий по количеству продуктов:"
      top_categories.each_with_index do |(cat_id, count), index|
        category = Category.find_by(ikea_id: cat_id)
        name = category ? category.name : 'Unknown'
        puts "    #{index + 1}. #{cat_id} (#{name}): #{count} продуктов"
      end
    end
    
    puts "\n💡 Выводы:"
    puts "  1. Продукт может быть привязан только к ОДНОЙ категории (belongs_to :category)"
    puts "  2. Когда задача get_products_all находит существующий продукт по SKU,"
    puts "     она обновляет его category_id, а не создает новый продукт"
    puts "  3. Поэтому общее количество продуктов увеличивается только когда:"
    puts "     - Найден продукт с новым SKU (которого еще нет в БД)"
    puts "     - Этот продукт создается через Product.create!"
    puts "  4. Когда продукт перепривязывается из одной категории в другую,"
    puts "     он 'переезжает' - старая категория теряет его, новая получает"
    
    puts "\n📝 Пример:"
    puts "  - Было: Продукт SKU '12345' привязан к категории '100'"
    puts "  - Запустили get_products_all для категории '200'"
    puts "  - Задача нашла продукт '12345' и обновила category_id с '100' на '200'"
    puts "  - Результат:"
    puts "    • Категория '100' потеряла продукт (теперь 0 продуктов)"
    puts "    • Категория '200' получила продукт (теперь 1 продукт)"
    puts "    • Общее количество продуктов в БД: без изменений (все еще 1)"
    
    puts "\n" + "=" * 80
    puts "Завершено"
    puts "=" * 80
  end
  
  desc "Детальный анализ распределения продуктов по категориям"
  task :analyze_products_distribution => :environment do
    puts "=" * 80
    puts "АНАЛИЗ: Распределение продуктов по категориям"
    puts "=" * 80
    
    # Основная статистика
    total_categories = Category.where(is_deleted: [false, nil]).count
    categories_with_products = Category.joins(:products).distinct.count
    categories_without_products = Category.left_joins(:products)
                                          .where(products: { id: nil })
                                          .where(is_deleted: [false, nil])
                                          .count
    total_products = Product.count
    
    puts "\n📊 ОСНОВНАЯ СТАТИСТИКА:"
    puts "  - Всего активных категорий: #{total_categories}"
    puts "  - Категорий с продуктами: #{categories_with_products}"
    puts "  - Категорий без продуктов: #{categories_without_products}"
    puts "  - Процент пустых категорий: #{((categories_without_products.to_f / total_categories) * 100).round(2)}%"
    puts "  - Всего продуктов в БД: #{total_products}"
    
    if categories_with_products > 0
      avg_products = (total_products.to_f / categories_with_products).round(2)
      puts "  - Среднее продуктов на категорию (с продуктами): #{avg_products}"
    end
    
    # Топ категории
    puts "\n📈 ТОП-10 КАТЕГОРИЙ ПО КОЛИЧЕСТВУ ПРОДУКТОВ:"
    top_categories = Category.select('categories.ikea_id, categories.name, COUNT(products.id) as products_count')
                             .joins(:products)
                             .group('categories.ikea_id, categories.name')
                             .order('products_count DESC')
                             .limit(10)
    
    top_total = 0
    top_categories.each_with_index do |cat, index|
      count = cat.respond_to?(:products_count) ? cat.products_count : cat.products.count
      top_total += count
      puts "  #{index + 1}. #{cat.ikea_id}: #{count} продуктов (#{cat.name[0..40]})"
    end
    puts "\n  Всего продуктов в топ-10: #{top_total} (#{((top_total.to_f / total_products) * 100).round(2)}% от общего количества)"
    
    # Категории без продуктов - детальный анализ
    puts "\n📦 КАТЕГОРИИ БЕЗ ПРОДУКТОВ - АНАЛИЗ:"
    
    empty_numeric = Category.left_joins(:products)
                           .where(products: { id: nil })
                           .where(is_deleted: [false, nil])
                           .where("categories.ikea_id ~ '^[0-9]+$'")
                           .count
    
    empty_uuid = Category.left_joins(:products)
                        .where(products: { id: nil })
                        .where(is_deleted: [false, nil])
                        .where("categories.ikea_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'")
                        .count
    
    empty_other = categories_without_products - empty_numeric - empty_uuid
    
    empty_with_url = Category.left_joins(:products)
                            .where(products: { id: nil })
                            .where(is_deleted: [false, nil])
                            .where.not(url: [nil, ''])
                            .count
    
    empty_without_url = categories_without_products - empty_with_url
    
    puts "  По типам ID:"
    puts "    - Числовые ID: #{empty_numeric}"
    puts "    - UUID ID: #{empty_uuid}"
    puts "    - Другие: #{empty_other}"
    puts "  По наличию URL:"
    puts "    - С URL: #{empty_with_url} (#{((empty_with_url.to_f / categories_without_products) * 100).round(2)}%)"
    puts "    - Без URL: #{empty_without_url} (#{((empty_without_url.to_f / categories_without_products) * 100).round(2)}%)"
    
    # Примеры пустых категорий с URL
    puts "\n🔍 ПРИМЕРЫ ПУСТЫХ КАТЕГОРИЙ С URL (первые 10):"
    empty_with_url_list = Category.left_joins(:products)
                                  .where(products: { id: nil })
                                  .where(is_deleted: [false, nil])
                                  .where.not(url: [nil, ''])
                                  .select('categories.ikea_id, categories.name, categories.url, categories.parent_ids')
                                  .limit(10)
    
    empty_with_url_list.each do |cat|
      id_type = if cat.numeric_id?
                  'Числовой'
                elsif cat.uuid_id?
                  'UUID'
                else
                  'Другой'
                end
      has_children = Category.normalize_parent_ids(cat.parent_ids).any? ? 
                     Category.where("parent_ids::text LIKE ?", "%\"#{cat.ikea_id}\"%").exists? : false
      
      puts "  - #{cat.ikea_id} (#{id_type}): #{cat.name[0..50]}"
      puts "    URL: #{cat.url}"
      puts "    Дочерних категорий: #{has_children ? 'есть' : 'нет'}"
    end
    
    # Анализ проблемы роста
    puts "\n💡 ВЫВОДЫ О ПРОБЛЕМЕ РОСТА:"
    puts "  1. В БД уже есть #{total_products} продуктов, все привязаны к категориям"
    puts "  2. #{categories_without_products} категорий (#{((categories_without_products.to_f / total_categories) * 100).round(2)}%) не имеют продуктов"
    puts "  3. Когда задача get_products_all находит продукт по SKU:"
    puts "     - Если продукт уже в БД → обновляется category_id (перепривязка)"
    puts "     - Если продукта нет в БД → создается новый продукт"
    puts "  4. Поэтому общее количество растет ТОЛЬКО когда:"
    puts "     - Найден продукт с НОВЫМ SKU (которого еще нет в БД)"
    puts "     - Все найденные продукты уже существуют → только перепривязка → рост = 0"
    
    puts "\n📝 РЕКОМЕНДАЦИИ:"
    puts "  1. Проверить пустые категории с URL через get_products[CATEGORY_ID]"
    puts "     Пример: rake categories:get_products[42926]"
    puts "  2. Запустить get_products_all для пустых категорий с числовыми ID:"
    puts "     Это потенциально может найти новые продукты"
    puts "  3. Обратить внимание на категории с дочерними категориями:"
    puts "     Возможно, продукты должны быть в дочерних категориях, а не в родительских"
    
    # Статистика по продуктам
    products_created_recently = Product.where('created_at > ?', 7.days.ago).count
    products_updated_recently = Product.where('updated_at > ?', 7.days.ago)
                                       .where('updated_at != created_at')
                                       .count
    
    puts "\n📅 ДИНАМИКА (последние 7 дней):"
    puts "  - Создано новых продуктов: #{products_created_recently}"
    puts "  - Обновлено продуктов: #{products_updated_recently}"
    
    if products_created_recently == 0 && products_updated_recently > 0
      puts "  ⚠️  Все продукты за последнюю неделю были ОБНОВЛЕНЫ, но не СОЗДАНЫ"
      puts "      Это подтверждает, что происходит только перепривязка, а не добавление новых"
    end
    
    puts "\n" + "=" * 80
    puts "Завершено"
    puts "=" * 80
  end
  
  desc "Исправить связи продуктов с категориями и добавить количество для существующих продуктов"
  task fix_product_links_and_quantity: :environment do
    puts "=" * 80
    puts "ИСПРАВЛЕНИЕ СВЯЗЕЙ И КОЛИЧЕСТВА ДЛЯ СУЩЕСТВУЮЩИХ ПРОДУКТОВ"
    puts "=" * 80
    puts ""
    
    stats = {
      products_processed: 0,
      links_created: 0,
      quantity_added: 0,
      errors: 0
    }
    
    # Обрабатываем продукты с category_id (старая связь)
    products_with_category = Product.where.not(category_id: [nil, ''])
    total = products_with_category.count
    
    puts "Найдено продуктов с category_id: #{total}"
    puts ""
    
    products_with_category.find_each(batch_size: 100) do |product|
      begin
        stats[:products_processed] += 1
        
        # 1. Создаем связь через CategoryProduct, если её нет
        if product.category_id.present?
          category = Category.find_by(ikea_id: product.category_id)
          if category
            unless CategoryProduct.exists?(product_id: product.id, category_id: category.ikea_id)
              CategoryProduct.create!(
                product: product,
                category_id: category.ikea_id
              )
              stats[:links_created] += 1
            end
          end
        end
        
        # 2. Добавляем количество, если его нет
        if product.quantity.blank? || product.quantity == 0
          # Пробуем получить из API
          if product.item_no.present?
            begin
              availability = IkeaApiService.check_availability([product.item_no])
              if availability[product.item_no.to_s] && availability[product.item_no.to_s][:quantity].present?
                quantity = availability[product.item_no.to_s][:quantity]
                product.update_column(:quantity, quantity)
                stats[:quantity_added] += 1
              end
            rescue => e
              # Игнорируем ошибки API
            end
          end
        end
        
        if stats[:products_processed] % 1000 == 0
          puts "Обработано: #{stats[:products_processed]} / #{total} (#{((stats[:products_processed].to_f / total) * 100).round(2)}%)"
        end
      rescue => e
        stats[:errors] += 1
        Rails.logger.error "Ошибка при обработке продукта #{product.sku}: #{e.message}"
      end
    end
    
    puts ""
    puts "=" * 80
    puts "РЕЗУЛЬТАТЫ:"
    puts "  - Обработано продуктов: #{stats[:products_processed]}"
    puts "  - Создано связей: #{stats[:links_created]}"
    puts "  - Добавлено количеств: #{stats[:quantity_added]}"
    puts "  - Ошибок: #{stats[:errors]}"
    puts "=" * 80
  end
end

