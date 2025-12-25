namespace :products do
  desc "Обновить все продукты 'Хиты продаж' через scrape.do"
  task update_bestsellers: :environment do
    puts "=== ОБНОВЛЕНИЕ ПРОДУКТОВ 'ХИТЫ ПРОДАЖ' ==="
    puts ""
    
    # Находим все продукты с флагом is_bestseller
    bestsellers = Product.where(is_bestseller: true)
    total_count = bestsellers.count
    
    puts "Найдено продуктов 'Хиты продаж': #{total_count}"
    puts ""
    
    if total_count == 0
      puts "⚠️  Нет продуктов с флагом is_bestseller = true"
      puts "   Запустите сначала ParseBestsellersJob для установки флагов"
      exit
    end
    
    stats = {
      processed: 0,
      updated: 0,
      errors: 0,
      images_downloaded: 0
    }
    
    bestsellers.find_each.with_index do |product, index|
      stats[:processed] += 1
      
      puts "[#{stats[:processed]}/#{total_count}] Обработка продукта: #{product.name} (SKU: #{product.sku})"
      
      begin
        # Проверяем наличие URL
        if product.url.blank?
          puts "  ⚠️  Пропущен: нет URL"
          stats[:errors] += 1
          next
        end
        
        # Формируем полный URL
        product_url = product.url.start_with?('http') ? product.url : "https://www.ikea.com#{product.url}"
        puts "  📄 URL: #{product_url}"
        
        # 1. Запрашиваем страницу через scrape.do для получения полных данных
        puts "  🔄 Запрос страницы через scrape.do..."
        scrape_do_html = ScrapeDoHelper.fetch_via_scrape_do(product_url)
        
        if scrape_do_html && scrape_do_html.length > 1000
          puts "  ✓ HTML получен (#{scrape_do_html.length} символов)"
          
          # Парсим HTML через PlDetailsFetcher
          puts "  🔄 Парсинг HTML через PlDetailsFetcher..."
          pl_details = PlDetailsFetcher.parse_html(scrape_do_html, product_url)
          
          if pl_details.present?
            puts "  ✓ Данные извлечены: цена=#{pl_details[:price]}, изображений=#{Array(pl_details[:images] || []).length}"
            
            # Подготавливаем данные для process_product
            puts "  🔄 Обновление данных продукта..."
            product_data = {
              'id' => product.sku,
              'sku' => product.sku,
              'itemNo' => product.item_no || pl_details[:sku],
              'name' => pl_details[:name] || product.name,
              'url' => product_url,
              'price' => pl_details[:price] || product.price,
              'images' => (Array(product.images || []) + Array(pl_details[:images] || [])).compact.uniq
            }
            
            # Используем метод process_product из ParseProductsJob
            category = product.category || Category.first
            if category
              job = ParseProductsJob.new
              job.send(:process_product, product_data, category)
              product.reload
              puts "  ✓ Данные обновлены"
              stats[:updated] += 1
            else
              puts "  ⚠️  Пропущен: нет категории"
              stats[:errors] += 1
              next
            end
          else
            puts "  ⚠️  Не удалось извлечь данные из HTML"
            stats[:errors] += 1
            next
          end
        else
          puts "  ⚠️  Не удалось получить HTML через scrape.do, используем обычный парсинг"
          # Fallback на обычный парсинг
          pl_details = PlDetailsFetcher.fetch(product_url)
          if pl_details.present?
            product_data = {
              'id' => product.sku,
              'sku' => product.sku,
              'itemNo' => product.item_no,
              'name' => product.name,
              'url' => product_url,
              'price' => product.price || pl_details[:price],
              'images' => (product.images || []) + Array(pl_details[:images] || [])
            }
            category = product.category || Category.first
            if category
              ParseProductsJob.new.send(:process_product, product_data, category)
              product.reload
              puts "  ✓ Данные обновлены (обычный парсинг)"
              stats[:updated] += 1
            end
          end
        end
        
        # 2. Загружаем изображения
        if product.images.present? || product.remote_images.present?
          image_urls = Array(product.images || product.remote_images || [])
          if image_urls.any?
            puts "  🖼️  Загрузка #{image_urls.length} изображений..."
            downloaded = ImageDownloader.download_product_images(product, image_urls)
            stats[:images_downloaded] += downloaded.length
            puts "  ✓ Загружено изображений: #{downloaded.length}"
          end
        end
        
        puts "  ✅ Продукт обработан успешно"
        puts ""
        
      rescue => e
        puts "  ❌ Ошибка: #{e.message}"
        puts "     #{e.backtrace.first(3).join("\n     ")}"
        stats[:errors] += 1
        puts ""
      end
    end
    
    puts ""
    puts "=== ИТОГИ ==="
    puts "Обработано: #{stats[:processed]}"
    puts "Обновлено: #{stats[:updated]}"
    puts "Ошибок: #{stats[:errors]}"
    puts "Изображений загружено: #{stats[:images_downloaded]}"
    puts ""
  end
end

# Вспомогательный модуль для работы с scrape.do
module ScrapeDoHelper
  def self.fetch_via_scrape_do(url)
    api_token = ENV.fetch('SCRAPE_DO_API_TOKEN', '752d361f2e444064955c30f0dd3b93b896726e4944e')
    api_url = "https://api.scrape.do/"
    
    uri = URI.parse(api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    http.open_timeout = 30
    
    params = {
      'token' => api_token,
      'url' => url,
      'format' => 'html',
      'render' => 'true',
      'wait' => '5000'
    }
    
    request_uri = "#{uri.path}?#{URI.encode_www_form(params)}"
    request = Net::HTTP::Get.new(request_uri)
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      Rails.logger.error "Scrape.do API error: HTTP #{response.code} - #{response.message}"
      nil
    end
  rescue => e
    Rails.logger.error "Scrape.do API exception: #{e.class} - #{e.message}"
    nil
  end
end

