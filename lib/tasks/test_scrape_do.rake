# Тестовый rake task для проверки scrape.do API
namespace :test do
  desc "Тест парсинга продукта через scrape.do API"
  task :scrape_do, [:product_id] => :environment do |t, args|
    begin
      product_id = args[:product_id] || 986
      product = Product.find(product_id)
      
      puts "=" * 80
      puts "ТЕСТ SCRAPE.DO API ДЛЯ ПРОДУКТА #{product_id}"
      puts "=" * 80
      puts ""
      puts "URL продукта: #{product.url}"
      puts "SKU: #{product.sku}"
      puts ""
      
      # API токен scrape.do
      api_token = '752d361f2e444064955c30f0dd3b93b896726e4944e'
      
      # URL для scrape.do API
      # Обычно формат: https://api.scrape.do/?token=TOKEN&url=URL
      api_url = "https://api.scrape.do/"
      
      puts "Отправляем запрос в scrape.do..."
      puts "API URL: #{api_url}"
      puts ""
      
      require 'net/http'
      require 'uri'
      require 'json'
      
      uri = URI.parse(api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60
      http.open_timeout = 30
      
      # Параметры запроса
      params = {
        'token' => api_token,
        'url' => product.url,
        'format' => 'html',
        'render' => 'true', # Для JavaScript рендеринга
        'wait' => '5000' # Ждем 5 секунд для загрузки JS
      }
      
      request_uri = "#{uri.path}?#{URI.encode_www_form(params)}"
      request = Net::HTTP::Get.new(request_uri)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      
      puts "Параметры запроса:"
      puts "  token: #{api_token[0..20]}..."
      puts "  url: #{product.url}"
      puts "  format: html"
      puts "  render: true"
      puts "  wait: 5000ms"
      puts ""
      
      start_time = Time.now
      response = http.request(request)
      elapsed_time = Time.now - start_time
      
      puts "Ответ получен за #{elapsed_time.round(2)} секунд"
      puts "HTTP статус: #{response.code} #{response.message}"
      puts ""
      
      if response.is_a?(Net::HTTPSuccess)
        html = response.body
        puts "HTML получен, длина: #{html.length} символов"
        puts ""
        
        # Сохраняем HTML в лог
        Rails.logger.info "=" * 80
        Rails.logger.info "SCRAPE.DO HTML ДЛЯ ПРОДУКТА #{product_id}"
        Rails.logger.info "=" * 80
        Rails.logger.info html[0..100000] # Первые 100KB
        
        # Парсим HTML
        require 'nokogiri'
        doc = Nokogiri::HTML(html)
        
        puts "Анализ полученного HTML:"
        puts "-" * 80
        
        # Проверяем наличие ключевых элементов
        checks = {
          'Модальное окно продукта' => doc.css('.pipf-product-details-modal').any?,
          'Кнопка "Informacje o produkcie"' => doc.css('button, a').any? { |btn| btn.text.to_s.include?('Informacje o produkcie') },
          'Описание продукта' => doc.css('.pipf-product-details-modal__paragraph').any?,
          'Материалы' => doc.css('.pipf-product-details-modal__material-header').any?,
          'Дизайнер' => doc.css('.pipf-product-details-modal__label').any? { |el| el.text.to_s.include?('Ganszyniec') },
          'Инструкции по уходу' => doc.css('.pipf-product-details-modal__care-header').any?,
          'Безопасность' => doc.css('h3').any? { |h| h.text.to_s.include?('Bezpieczeństwo') },
          'Документы' => doc.css('.pipf-product-details-modal__document-link').any?
        }
        
        checks.each do |name, found|
          status = found ? '✓' : '✗'
          puts "  #{status} #{name}"
        end
        
        puts ""
        
        # Извлекаем данные из модального окна
        modal = doc.css('.pipf-product-details-modal').first
        
        if modal
          puts "=" * 80
          puts "ДАННЫЕ ИЗ МОДАЛЬНОГО ОКНА"
          puts "=" * 80
          puts ""
          
          # Описание
          paragraphs = modal.css('.pipf-product-details-modal__paragraph').map(&:text).map(&:strip)
          if paragraphs.any?
            puts "Описание (#{paragraphs.length} параграфов):"
            paragraphs.each_with_index do |p, idx|
              puts "  #{idx + 1}. #{p[0..150]}..."
            end
            puts ""
          end
          
          # Дизайнер
          designer_label = modal.css('.pipf-product-details-modal__header').find { |el| el.text.to_s.include?('Projektant') || el.text.to_s.include?('Дизайнер') }
          if designer_label
            designer = designer_label.next_element&.text&.strip || designer_label.parent.css('.pipf-product-details-modal__label').first&.text&.strip
            puts "Дизайнер: #{designer}" if designer
            puts ""
          end
          
          # Материалы
          materials_header = modal.css('.pipf-product-details-modal__material-header').first
          if materials_header
            puts "Материалы:"
            materials_section = materials_header.parent || materials_header.next_element
            materials_section.css('dl.pipf-product-details-modal__section').each do |dl|
              dt = dl.css('dt').first&.text&.strip
              dd = dl.css('dd').first&.text&.strip
              if dt && dd
                puts "  - #{dt}: #{dd[0..100]}"
              end
            end
            puts ""
          end
          
          # Инструкции по уходу
          care_header = modal.css('.pipf-product-details-modal__care-header').first
          if care_header
            puts "Инструкции по уходу:"
            care_section = care_header.parent || care_header.next_element
            care_section.css('.pipf-product-details-modal__label').each do |label|
              text = label.text.strip
              puts "  - #{text}" if text.present?
            end
            puts ""
          end
          
          # Безопасность
          safety_section = modal.css('h3').find { |h| h.text.to_s.include?('Bezpieczeństwo') }
          if safety_section
            puts "Безопасность:"
            safety_section.parent.css('.pipf-product-details-modal__paragraph').each do |p|
              text = p.text.strip
              puts "  - #{text[0..200]}..." if text.present?
            end
            puts ""
          end
          
          # Документы
          documents = modal.css('.pipf-product-details-modal__document-link')
          if documents.any?
            puts "Документы (#{documents.length}):"
            documents.each do |doc_link|
              href = doc_link['href']
              text = doc_link.text.strip
              puts "  - #{text}: #{href}"
            end
            puts ""
          end
          
          # "Полезно знать"
          good_to_know = modal.css('h3').find { |h| h.text.to_s.include?('Dobrze wiedzieć') || h.text.to_s.include?('Полезно знать') }
          if good_to_know
            puts "Полезно знать:"
            good_to_know.parent.css('.pipf-product-details-modal__paragraph').each do |p|
              text = p.text.strip
              puts "  - #{text}" if text.present?
            end
            puts ""
          end
        else
          puts "Модальное окно не найдено в HTML"
          puts ""
          puts "Первые 2000 символов HTML:"
          puts html[0..2000]
          puts ""
        end
        
        puts "=" * 80
        puts "ТЕСТ ЗАВЕРШЕН"
        puts "=" * 80
        puts ""
        puts "Полный HTML сохранен в log/development.log"
        
      else
        puts "ОШИБКА: HTTP #{response.code} - #{response.message}"
        puts ""
        puts "Тело ответа:"
        puts response.body[0..1000]
      end
      
    rescue => e
      puts "ОШИБКА: #{e.class} - #{e.message}"
      puts e.backtrace.first(10).join("\n")
    end
  end
end

