# Rake задачи для управления парсером
namespace :parser do
  desc "Синхронизировать все cron расписания"
  task sync_cron: :environment do
    puts "Синхронизация cron расписаний..."
    CronManagerService.sync_all_schedules
    puts "Готово!"
  end

  desc "Проверить и запустить задачи, которые должны выполниться"
  task check_due_tasks: :environment do
    puts "Проверка задач для выполнения..."
    CronManagerService.check_and_run_due_tasks
    puts "Готово!"
  end

  desc "Запустить парсинг категорий"
  task :parse_categories, [:limit] => :environment do |_t, args|
    limit = args[:limit]&.to_i
    puts "Запуск парсинга категорий (лимит: #{limit || 'без ограничений'})..."
    ParseCategoriesJob.perform_later(limit: limit)
    puts "Задача поставлена в очередь"
  end

  desc "Запустить парсинг продуктов"
  task :parse_products, [:limit] => :environment do |_t, args|
    limit = args[:limit]&.to_i
    puts "Запуск парсинга продуктов (лимит: #{limit || 'без ограничений'})..."
    ParseProductsJob.perform_later(limit: limit)
    puts "Задача поставлена в очередь"
  end

  desc "Запустить парсинг хитов продаж"
  task :parse_bestsellers, [:limit] => :environment do |_t, args|
    limit = args[:limit]&.to_i
    puts "Запуск парсинга хитов продаж (лимит: #{limit || 'без ограничений'})..."
    ParseBestsellersJob.perform_later(limit: limit)
    puts "Задача поставлена в очередь"
  end

  desc "Запустить парсинг популярных категорий"
  task :parse_popular_categories, [:limit] => :environment do |_t, args|
    limit = args[:limit]&.to_i
    puts "Запуск парсинга популярных категорий (лимит: #{limit || 'без ограничений'})..."
    ParsePopularCategoriesJob.perform_later(limit: limit)
    puts "Задача поставлена в очередь"
  end

  desc "Загрузить изображения категорий"
  task :download_category_images, [:limit] => :environment do |_t, args|
    limit = args[:limit]&.to_i
    puts "Загрузка изображений категорий (лимит: #{limit || 'без ограничений'})..."
    DownloadCategoryImagesJob.perform_later(limit: limit)
    puts "Задача поставлена в очередь"
  end

  desc "Загрузить изображения продуктов"
  task :download_product_images, [:limit] => :environment do |_t, args|
    limit = args[:limit]&.to_i
    puts "Загрузка изображений продуктов (лимит: #{limit || 'без ограничений'})..."
    DownloadProductImagesJob.perform_later(limit: limit)
    puts "Задача поставлена в очередь"
  end

  desc "Очистка БД: категории, продукты и связанные ресурсы (картинки)"
  task clean_db: :environment do
    puts "=" * 60
    puts "Очистка базы данных и файлов"
    puts "=" * 60
    
    # Удаляем записи из БД
    puts "\nУдаление категорий и продуктов..."
    categories_count = Category.count
    products_count = Product.count
    
    Category.destroy_all
    Product.destroy_all
    
    puts "  ✓ Удалено категорий: #{categories_count}"
    puts "  ✓ Удалено продуктов: #{products_count}"
    
    # Удаляем картинки
    puts "\nУдаление картинок..."
    images_path = Rails.root.join('public', 'images')
    
    if images_path.exist?
      categories_path = images_path.join('categories')
      products_path = images_path.join('products')
      
      if categories_path.exist?
        categories_deleted = Dir.glob(categories_path.join('*')).count
        FileUtils.rm_rf(categories_path)
        puts "  ✓ Удалено картинок категорий: #{categories_deleted}"
      end
      
      if products_path.exist?
        products_deleted = Dir.glob(products_path.join('**', '*')).count
        FileUtils.rm_rf(products_path)
        puts "  ✓ Удалено картинок продуктов: #{products_deleted}"
      end
    end
    
    # Очищаем кэш переводов (опционально)
    puts "\nОчистка кэша переводов..."
    translation_cache_count = TranslationCache.count
    TranslationCache.destroy_all
    puts "  ✓ Удалено записей кэша: #{translation_cache_count}"
    
    puts "\n" + "=" * 60
    puts "Очистка завершена!"
    puts "=" * 60
  end

  desc "Тестовый парсинг: 10 категорий и по 10 продуктов для каждой (синхронно)"
  task test_parse: :environment do
    categories_limit = 10
    products_per_category = 10
    
    puts "=" * 60
    puts "Начинаем тестовый парсинг"
    puts "Категории: #{categories_limit}"
    puts "Продуктов на категорию: #{products_per_category}"
    puts "=" * 60
    
    # Шаг 1: Парсинг категорий
    puts "\n[1/2] Парсинг категорий..."
    
    # Проверяем, что API доступен
    puts "Проверка доступности API..."
    api_available = false
    begin
      categories_data = IkeaApiService.fetch_categories
      if categories_data.present?
        api_available = true
        puts "✓ API доступен, получены данные: #{categories_data.class}"
        if categories_data.is_a?(Hash)
          puts "  Ключи в ответе: #{categories_data.keys.first(10).join(', ')}"
        elsif categories_data.is_a?(Array)
          puts "  Количество элементов в массиве: #{categories_data.length}"
        end
      else
        puts "⚠ API вернул nil, используем существующие категории"
      end
    rescue => e
      puts "⚠ Ошибка при запросе к API: #{e.message}"
      puts "  Используем существующие категории"
    end
    
    # Пытаемся парсить категории через API, если доступен
    if api_available
      begin
        ParseCategoriesJob.new.perform(limit: categories_limit)
        puts "✓ Парсинг категорий через API завершён"
      rescue => e
        puts "⚠ Ошибка при парсинге категорий: #{e.message}"
        puts "  Используем существующие категории"
      end
    end
    
    # Получаем первые 10 категорий (либо из API, либо существующие)
    # Исключаем тестовые категории
    categories = Category.not_deleted.where.not('ikea_id LIKE ?', 'test_category_%').limit(categories_limit)
    puts "\nНайдено категорий: #{categories.count}"
    
    if categories.empty?
      puts "⚠ Категории не найдены. Попробуйте запустить парсинг категорий вручную."
      puts "  rake parser:parse_categories[10]"
      exit 1
    end
    
    # Шаг 2: Парсинг продуктов для каждой категории
    puts "\n[2/2] Парсинг продуктов для каждой категории..."
    total_products = 0
    total_errors = 0
    
    categories.each_with_index do |category, index|
      puts "\n  Категория #{index + 1}/#{categories.count}: #{category.name} (ID: #{category.ikea_id})"
      
      begin
        ParseProductsJob.new.perform(limit: products_per_category, category_id: category.ikea_id)
        products_count = Product.where(category_id: category.ikea_id).count
        total_products += products_count
        if products_count > 0
          puts "    ✓ Загружено продуктов: #{products_count}"
        else
          puts "    ⚠ Продукты не найдены (возможно, API недоступен или категория не содержит продуктов)"
        end
      rescue => e
        total_errors += 1
        puts "    ✗ Ошибка: #{e.message}"
        puts "      #{e.class}" if e.class != StandardError
      end
    end
    
    puts "\n" + "=" * 60
    puts "Тестовый парсинг завершён!"
    puts "Категорий: #{categories.count}"
    puts "Всего продуктов: #{total_products}"
    puts "Ошибок: #{total_errors}" if total_errors > 0
    puts "=" * 60
    
    # Шаг 3: Загрузка картинок (автоматически после парсинга)
    if total_products > 0
      puts "\n[3/3] Загрузка картинок..."
      
      # Загружаем картинки категорий
      puts "\n  Загрузка картинок категорий..."
      begin
        categories_with_images = Category.where.not(remote_image_url: [nil, '']).limit(categories_limit)
        if categories_with_images.any?
          DownloadCategoryImagesJob.new.perform(limit: categories_limit)
          categories_downloaded = Category.where.not(local_image_path: [nil, '']).count
          puts "    ✓ Загружено картинок категорий: #{categories_downloaded}"
        else
          puts "    ⚠ Нет категорий с remote_image_url"
        end
      rescue => e
        puts "    ✗ Ошибка загрузки картинок категорий: #{e.message}"
      end
      
      # Загружаем картинки продуктов
      puts "\n  Загрузка картинок продуктов..."
      begin
        products_with_images = Product.where.not(images: [nil, '[]']).limit(total_products)
        if products_with_images.any?
          DownloadProductImagesJob.new.perform(limit: total_products, images_limit: 5)
          products_downloaded = Product.where.not(local_images: [nil, '[]']).count
          puts "    ✓ Загружено картинок продуктов: #{products_downloaded} (по 5 на продукт)"
        else
          puts "    ⚠ Нет продуктов с remote images"
        end
      rescue => e
        puts "    ✗ Ошибка загрузки картинок продуктов: #{e.message}"
      end
      
      puts "\n" + "=" * 60
      puts "Загрузка картинок завершена!"
      puts "=" * 60
    end
    
    if total_products == 0 && !api_available
      puts "\n⚠ ВНИМАНИЕ: API IKEA недоступен (403 Forbidden)"
      puts "Для работы парсера необходимо:"
      puts "  1. Настроить прокси-серверы в переменной окружения PROXY_LIST"
      puts "  2. Или проверить доступность API IKEA"
      puts "  3. Или использовать VPN/другой способ обхода блокировки"
      puts "\nПример настройки прокси:"
      puts "  export PROXY_LIST='http://proxy1:port,http://proxy2:port'"
    end
  end
end


