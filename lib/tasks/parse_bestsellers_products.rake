# Rake task для парсинга продуктов из списка "Хиты продаж"
namespace :parser do
  desc "Парсинг продуктов из списка 'Хиты продаж' (максимум 10)"
  task :parse_bestsellers_products => :environment do
    begin
      puts "=" * 80
      puts "ПАРСИНГ ПРОДУКТОВ ИЗ СПИСКА 'ХИТЫ ПРОДАЖ'"
      puts "=" * 80
      puts ""
      
      # Получаем список хитов продаж
      puts "Получаем список 'Хиты продаж' с главной страницы..."
      result = HomepageFetcher.fetch
      skus = result[:bestseller_skus].first(10)
      product_urls = result[:bestseller_urls] || {}
      
      if skus.empty?
        puts "ОШИБКА: Список 'Хиты продаж' пуст"
        exit 1
      end
      
      puts "Найдено SKU: #{skus.length}"
      puts "Найдено URL: #{product_urls.length}"
      puts "SKU: #{skus.inspect}"
      puts ""
      
      # Создаем задачу парсинга
      task = ParserTask.create!(
        task_type: 'products',
        status: 'running',
        limit: skus.length,
        started_at: Time.current
      )
      
      stats = {
        processed: 0,
        created: 0,
        updated: 0,
        errors: 0
      }
      
      job = ParseProductsJob.new
      
      skus.each_with_index do |sku, index|
        puts "-" * 80
        puts "Обработка продукта #{index + 1}/#{skus.length}: SKU = #{sku}"
        puts "-" * 80
        
        begin
          # Нормализуем SKU
          normalized_sku = sku.to_s.strip.gsub(/[.\-\s]/, '')
          
          # Проверяем, существует ли продукт
          existing_product = Product.find_by(sku: normalized_sku) || 
                             Product.find_by(sku: normalized_sku.gsub(/^s/i, ''))
          
          if existing_product
            puts "Продукт уже существует: #{existing_product.name} (SKU: #{existing_product.sku})"
            puts "Обновляем статус is_bestseller = true"
            existing_product.update!(is_bestseller: true) unless existing_product.is_bestseller
            stats[:updated] += 1
            stats[:processed] += 1
            task.increment_processed!
            next
          end
          
          # Получаем URL продукта
          url = product_urls[normalized_sku] || product_urls[sku]
          
          unless url
            puts "✗ URL не найден для SKU #{sku}"
            stats[:errors] += 1
            stats[:processed] += 1
            task.increment_processed!
            next
          end
          
          puts "Используем URL: #{url}"
          
          # Парсим продукт через PlDetailsFetcher
          begin
            puts "Парсим продукт через PlDetailsFetcher..."
            pl_details = PlDetailsFetcher.fetch(url)
            
            unless pl_details.present? && pl_details[:sku]
              puts "✗ PlDetailsFetcher не вернул данные"
              stats[:errors] += 1
              stats[:processed] += 1
              task.increment_processed!
              next
            end
            
            puts "✓ Данные получены через PlDetailsFetcher"
            
            # Создаем структуру product_data из pl_details
            product_data = {
              'id' => pl_details[:sku],
              'itemNoGlobal' => pl_details[:sku],
              'typeName' => pl_details[:name] || pl_details[:name_ru],
              'pipUrl' => url,
              'salesPrice' => { 'numeral' => pl_details[:price] }
            }
            
            # Определяем категорию (пробуем найти по контексту или используем первую доступную)
            category = Category.not_deleted.first
            if category.nil?
              puts "ОШИБКА: Нет категорий в БД. Сначала запустите ParseCategoriesJob."
              stats[:errors] += 1
              stats[:processed] += 1
              task.increment_processed!
              next
            end
            
            puts "Парсим продукт через ParseProductsJob.process_product..."
            process_result = job.send(:process_product, product_data.with_indifferent_access, category)
            
            # Ищем продукт после обработки (может быть создан или обновлен)
            # Используем SKU из product_data (который был извлечен из pl_details)
            product_sku = product_data['id'] || product_data['itemNoGlobal'] || normalized_sku
            product_sku_normalized = product_sku.to_s.gsub(/[.\-\s]/, '')
            
            product = Product.find_by(sku: product_sku) ||
                     Product.find_by(sku: product_sku_normalized) ||
                     Product.find_by(sku: normalized_sku) || 
                     Product.find_by(sku: normalized_sku.gsub(/^s/i, ''))
            
            if product
              # Устанавливаем is_bestseller = true
              was_bestseller = product.is_bestseller
              product.update!(is_bestseller: true) unless product.is_bestseller
              puts "✓ Продукт успешно сохранен: #{product.name} (SKU: #{product.sku})"
              puts "  Статус: is_bestseller = #{product.is_bestseller} (было: #{was_bestseller})"
              
              if process_result[:created]
                stats[:created] += 1
              elsif process_result[:updated]
                stats[:updated] += 1
              else
                # Если продукт уже был в БД, считаем обновлением
                stats[:updated] += 1
              end
            else
              puts "✗ Продукт не найден в БД после обработки (искали по: #{product_sku}, #{product_sku_normalized}, #{normalized_sku})"
              stats[:errors] += 1
            end
            
            stats[:processed] += 1
            task.increment_processed!
            
          rescue => e
            puts "✗ Ошибка при парсинге через PlDetailsFetcher: #{e.class} - #{e.message}"
            puts e.backtrace.first(3).join("\n")
            stats[:errors] += 1
            task.increment_errors!
            stats[:processed] += 1
            task.increment_processed!
          end
          
        rescue => e
          puts "ОШИБКА при обработке SKU #{sku}: #{e.class} - #{e.message}"
          puts e.backtrace.first(5).join("\n")
          stats[:errors] += 1
          task.increment_errors!
          stats[:processed] += 1
          task.increment_processed!
        end
        
        puts ""
      end
      
      # Завершаем задачу
      task.mark_as_completed!(stats)
      
      puts "=" * 80
      puts "ПАРСИНГ ЗАВЕРШЕН"
      puts "=" * 80
      puts ""
      puts "Статистика:"
      puts "  Обработано: #{stats[:processed]}"
      puts "  Создано: #{stats[:created]}"
      puts "  Обновлено: #{stats[:updated]}"
      puts "  Ошибок: #{stats[:errors]}"
      puts ""
      
    rescue => e
      puts "КРИТИЧЕСКАЯ ОШИБКА: #{e.class} - #{e.message}"
      puts e.backtrace.first(10).join("\n")
      task&.mark_as_failed!(e.message) if task
    end
  end
end
