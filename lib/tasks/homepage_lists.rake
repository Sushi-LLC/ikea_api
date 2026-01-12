# Rake задачи для вывода списков с главной страницы IKEA
namespace :homepage do
  desc "Вывести список популярных категорий и хитов продаж с главной страницы"
  desc "Использование: rake homepage:list[true] - для обновления флагов is_bestseller и is_popular"
  task :list, [:update] => :environment do |_t, args|
    update_flags = args[:update] == 'true'
    
    puts "=" * 80
    puts "ПОПУЛЯРНЫЕ КАТЕГОРИИ И ХИТЫ ПРОДАЖ С ГЛАВНОЙ СТРАНИЦЫ IKEA"
    if update_flags
      puts "⚠️  РЕЖИМ ОБНОВЛЕНИЯ: флаги is_bestseller и is_popular будут обновлены"
    end
    puts "=" * 80
    puts
    
    begin
      result = HomepageFetcher.fetch
      
      # Выводим популярные категории
      puts "📁 ПОПУЛЯРНЫЕ КАТЕГОРИИ"
      puts "-" * 80
      
      if result[:popular_category_ids].empty?
        puts "  ⚠️  Популярные категории не найдены"
        puts "  💡 Источник: главная страница IKEA (https://www.ikea.com/pl/pl/)"
        puts "     Парсер ищет секцию 'Популярные категории' / 'Popular categories'"
      else
        puts "  Найдено категорий: #{result[:popular_category_ids].length}"
        puts "  💡 Источник: главная страница IKEA (https://www.ikea.com/pl/pl/)"
        puts "     Парсер извлекает категории из секции 'Популярные категории' и ссылок на странице"
        puts
        
        updated_categories_count = 0
        
        result[:popular_category_ids].each_with_index do |category_id, index|
          category_info = result[:popular_category_urls][category_id] || {}
          url = category_info[:url] || category_id
          name = category_info[:name]
          
          # Пробуем найти категорию в БД
          category = nil
          if category_id.match(/^\d+$/)
            category = Category.find_by(ikea_id: category_id)
          elsif url.present?
            # Ищем по URL
            if url.include?('/cat/')
              slug = url.split('/cat/').last.split('/').first
              category = Category.where("url LIKE ?", "%#{slug}%").first if slug
            end
          end
          
          # Обновляем флаг, если указана опция update
          was_popular = category&.is_popular
          if update_flags && category && !category.is_popular
            category.update!(is_popular: true)
            updated_categories_count += 1
            was_popular = false # Для отображения изменения
          end
          
          puts "  #{index + 1}. #{name || category&.name || 'Без названия'}"
          puts "     ID: #{category_id}"
          if url != category_id
            puts "     URL: #{url}"
          end
          if category
            current_popular = category.reload.is_popular
            status_text = "is_popular=#{current_popular}"
            if update_flags && was_popular != current_popular
              status_text += " (было: #{was_popular} → обновлено)"
            end
            puts "     ✓ Найдена в БД: #{category.name} (ikea_id: #{category.ikea_id})"
            puts "     Статус: #{status_text}"
          else
            puts "     ⚠️  Не найдена в БД"
          end
          puts
        end
        
        if update_flags && updated_categories_count > 0
          puts "  ✅ Обновлено флагов is_popular: #{updated_categories_count}"
          puts
        end
      end
      
      puts
      puts "🔥 ХИТЫ ПРОДАЖ"
      puts "-" * 80
      
      if result[:bestseller_skus].empty?
        puts "  ⚠️  Хиты продаж не найдены"
        puts "  💡 Источник: главная страница IKEA (https://www.ikea.com/pl/pl/)"
        puts "     Парсер ищет секцию 'Хиты продаж' / 'Bestsellers' / 'Hity'"
      else
        puts "  Найдено продуктов: #{result[:bestseller_skus].length}"
        puts "  💡 Источник: главная страница IKEA (https://www.ikea.com/pl/pl/)"
        puts "     Парсер извлекает продукты из секции 'Хиты продаж' и скриптов страницы"
        puts "     ⚠️  На главной странице обычно показывается ограниченное количество (10-20)"
        puts "        Для получения всех хитов продаж используйте: rake parser:parse_bestsellers"
        puts
        
        updated_count = 0
        
        result[:bestseller_skus].each_with_index do |sku, index|
          url = result[:bestseller_urls][sku]
          name = result[:bestseller_names][sku]
          
          # Пробуем найти продукт в БД
          product = Product.find_by(sku: sku)
          unless product
            # Пробуем варианты SKU
            sku_without_s = sku.gsub(/^s/i, '')
            product = Product.find_by(sku: sku_without_s) if sku_without_s != sku
            product ||= Product.find_by(sku: "s#{sku_without_s}") if sku_without_s != sku && !product
          end
          
          # Обновляем флаг, если указана опция update
          was_bestseller = product&.is_bestseller
          if update_flags && product && !product.is_bestseller
            product.update!(is_bestseller: true)
            updated_count += 1
            was_bestseller = false # Для отображения изменения
          end
          
          puts "  #{index + 1}. #{name || product&.name || 'Без названия'}"
          puts "     SKU: #{sku}"
          if url
            puts "     URL: #{url}"
          end
          if product
            current_bestseller = product.reload.is_bestseller
            status_text = "is_bestseller=#{current_bestseller}"
            if update_flags && was_bestseller != current_bestseller
              status_text += " (было: #{was_bestseller} → обновлено)"
            end
            puts "     ✓ Найден в БД: #{product.name} (SKU: #{product.sku})"
            puts "     Статус: #{status_text}"
            if product.price
              puts "     Цена: #{product.price} PLN"
            end
          else
            puts "     ⚠️  Не найден в БД"
          end
          puts
        end
        
        if update_flags && updated_count > 0
          puts "  ✅ Обновлено флагов is_bestseller: #{updated_count}"
          puts
        end
      end
      
      puts
      puts "=" * 80
      puts "ИТОГО:"
      puts "  Популярных категорий: #{result[:popular_category_ids].length}"
      puts "  Хитов продаж: #{result[:bestseller_skus].length}"
      if !update_flags
        puts
        puts "💡 Используйте: rake homepage:list[true] для автоматического обновления флагов"
      end
      puts "=" * 80
      
    rescue => e
      puts "❌ Ошибка при получении данных: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
  
  desc "Вывести только список популярных категорий"
  task :list_categories => :environment do
    puts "=" * 80
    puts "ПОПУЛЯРНЫЕ КАТЕГОРИИ С ГЛАВНОЙ СТРАНИЦЫ IKEA"
    puts "=" * 80
    puts
    
    begin
      result = HomepageFetcher.fetch
      
      if result[:popular_category_ids].empty?
        puts "  ⚠️  Популярные категории не найдены"
      else
        puts "  Найдено категорий: #{result[:popular_category_ids].length}"
        puts
        
        result[:popular_category_ids].each_with_index do |category_id, index|
          category_info = result[:popular_category_urls][category_id] || {}
          url = category_info[:url] || category_id
          name = category_info[:name]
          
          category = nil
          if category_id.match(/^\d+$/)
            category = Category.find_by(ikea_id: category_id)
          elsif url.present? && url.include?('/cat/')
            slug = url.split('/cat/').last.split('/').first
            category = Category.where("url LIKE ?", "%#{slug}%").first if slug
          end
          
          puts "#{index + 1}. #{name || category&.name || category_id}"
          puts "   ID: #{category_id}"
          puts "   URL: #{url}" if url != category_id
          puts "   В БД: #{category ? '✓ ' + category.name : '✗ не найдена'}"
        end
      end
      
    rescue => e
      puts "❌ Ошибка: #{e.message}"
      exit 1
    end
  end
  
  desc "Вывести только список хитов продаж"
  task :list_bestsellers => :environment do
    puts "=" * 80
    puts "ХИТЫ ПРОДАЖ С ГЛАВНОЙ СТРАНИЦЫ IKEA"
    puts "=" * 80
    puts
    
    begin
      result = HomepageFetcher.fetch
      
      if result[:bestseller_skus].empty?
        puts "  ⚠️  Хиты продаж не найдены"
      else
        puts "  Найдено продуктов: #{result[:bestseller_skus].length}"
        puts
        
        result[:bestseller_skus].each_with_index do |sku, index|
          url = result[:bestseller_urls][sku]
          name = result[:bestseller_names][sku]
          
          product = Product.find_by(sku: sku)
          unless product
            sku_without_s = sku.gsub(/^s/i, '')
            product = Product.find_by(sku: sku_without_s) if sku_without_s != sku
            product ||= Product.find_by(sku: "s#{sku_without_s}") if sku_without_s != sku && !product
          end
          
          puts "#{index + 1}. #{name || product&.name || sku}"
          puts "   SKU: #{sku}"
          puts "   URL: #{url}" if url
          puts "   В БД: #{product ? '✓ ' + product.name : '✗ не найден'}"
          puts "   Цена: #{product.price} PLN" if product&.price
        end
      end
      
    rescue => e
      puts "❌ Ошибка: #{e.message}"
      exit 1
    end
  end
end
