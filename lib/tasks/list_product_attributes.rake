# Rake task для формирования полного списка атрибутов продукта
namespace :products do
  desc "Формирование полного списка атрибутов продукта на основе scrape.do"
  task :list_attributes, [:product_id] => :environment do |t, args|
    begin
      product_id = args[:product_id] || 986
      product = Product.find(product_id)
      
      puts "=" * 80
      puts "ПОЛНЫЙ СПИСОК АТРИБУТОВ ПРОДУКТА #{product_id}"
      puts "=" * 80
      puts ""
      puts "URL: #{product.url}"
      puts "SKU: #{product.sku}"
      puts "item_no: #{product.item_no}"
      puts ""
      
      # Получаем данные через scrape.do
      api_token = ENV.fetch('SCRAPE_DO_API_TOKEN', '752d361f2e444064955c30f0dd3b93b896726e4944e')
      api_url = "https://api.scrape.do/"
      
      require 'net/http'
      require 'uri'
      require 'nokogiri'
      
      uri = URI.parse(api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60
      
      params = {
        'token' => api_token,
        'url' => product.url,
        'format' => 'html',
        'render' => 'true',
        'wait' => '5000'
      }
      
      request_uri = "#{uri.path}?#{URI.encode_www_form(params)}"
      request = Net::HTTP::Get.new(request_uri)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      
      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        puts "ОШИБКА: HTTP #{response.code}"
        exit 1
      end
      
      html = response.body
      doc = Nokogiri::HTML(html)
      
      # Извлекаем все данные
      attributes = {}
      
      # ============================================
      # 1. БАЗОВЫЕ АТРИБУТЫ
      # ============================================
      puts "1. БАЗОВЫЕ АТРИБУТЫ"
      puts "-" * 80
      
      # JSON-LD данные
      json_ld = doc.css('script[type="application/ld+json"]').find { |s| s.text.include?('"@type":"Product"') }
      if json_ld
        begin
          schema = JSON.parse(json_ld.text)
          if schema['@type'] == 'Product'
            attributes[:name] = schema['name']
            attributes[:sku] = schema['mpn'] || schema['sku']
            attributes[:price] = schema.dig('offers', 'price')
            attributes[:images] = Array(schema['image'])
            attributes[:url] = schema['url'] || schema.dig('offers', 'url')
            
            if schema['width'] || schema['height'] || schema['depth']
              width = schema['width']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
              height = schema['height']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
              depth = schema['depth']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
              attributes[:dimensions] = "#{width} × #{depth} × #{height || 'N/A'} cm" if width && depth
            end
          end
        rescue JSON::ParserError
        end
      end
      
      # Вес из HTML
      weight_match = html.match(/(\d+[.,]\d+)\s*kg/i)
      attributes[:weight] = weight_match[1].gsub(',', '.') if weight_match
      
      # Коллекция
      collection = doc.css('.pip-header-section__title--big').first&.text&.strip
      attributes[:collection] = collection if collection.present?
      
      # Выводим базовые атрибуты
      puts "  ✓ Название: #{attributes[:name] || 'Нет'}"
      puts "  ✓ SKU: #{attributes[:sku] || 'Нет'}"
      puts "  ✓ Цена: #{attributes[:price] || 'Нет'}"
      puts "  ✓ Вес: #{attributes[:weight] || 'Нет'} кг"
      puts "  ✓ Размеры: #{attributes[:dimensions] || 'Нет'}"
      puts "  ✓ Коллекция: #{attributes[:collection] || 'Нет'}"
      puts "  ✓ Изображения: #{attributes[:images]&.length || 0}"
      puts ""
      
      # ============================================
      # 2. ОПИСАНИЕ ПРОДУКТА
      # ============================================
      puts "2. ОПИСАНИЕ ПРОДУКТА"
      puts "-" * 80
      
      modal = doc.css('.pipf-product-details-modal').first
      
      if modal
        # Полное описание (все параграфы)
        description_paragraphs = modal.css('.pipf-product-details-modal__paragraph').map(&:text).map(&:strip).reject(&:blank?)
        attributes[:description] = description_paragraphs.join("\n\n")
        attributes[:description_paragraphs] = description_paragraphs
        
        # Краткое описание (первый параграф)
        attributes[:short_description] = description_paragraphs.first if description_paragraphs.any?
        
        puts "  ✓ Полное описание: #{description_paragraphs.length} параграфов"
        puts "  ✓ Краткое описание: #{attributes[:short_description].present? ? 'Есть' : 'Нет'}"
        if description_paragraphs.any?
          puts "    Первый параграф: #{description_paragraphs.first[0..150]}..."
        end
        puts ""
        
        # ============================================
        # 3. ДИЗАЙНЕР
        # ============================================
        puts "3. ДИЗАЙНЕР"
        puts "-" * 80
        
        designer_label = modal.css('.pipf-product-details-modal__header').find { |el| 
          el.text.to_s.include?('Projektant') || 
          el.text.to_s.include?('Дизайнер') ||
          el.text.to_s.include?('Designer')
        }
        
        if designer_label
          designer = designer_label.next_element&.text&.strip || 
                    designer_label.parent.css('.pipf-product-details-modal__label').first&.text&.strip
          attributes[:designer] = designer if designer.present?
        end
        
        puts "  #{attributes[:designer].present? ? '✓' : '✗'} Дизайнер: #{attributes[:designer] || 'Нет'}"
        puts ""
        
        # ============================================
        # 4. МАТЕРИАЛЫ
        # ============================================
        puts "4. МАТЕРИАЛЫ"
        puts "-" * 80
        
        materials_header = modal.css('.pipf-product-details-modal__material-header').first
        if materials_header
          materials_section = materials_header.parent || materials_header.next_element
          materials_list = []
          
          materials_section.css('dl.pipf-product-details-modal__section').each do |dl|
            dt = dl.css('dt').first&.text&.strip
            dd = dl.css('dd').first&.text&.strip
            if dt && dd
              materials_list << "#{dt}: #{dd}"
            end
          end
          
          attributes[:materials] = materials_list.join("\n")
          attributes[:materials_list] = materials_list
          
          puts "  ✓ Материалы: #{materials_list.length} элементов"
          materials_list.each_with_index do |mat, idx|
            puts "    #{idx + 1}. #{mat[0..100]}"
          end
        else
          puts "  ✗ Материалы: Нет"
        end
        puts ""
        
        # ============================================
        # 5. ИНСТРУКЦИИ ПО УХОДУ
        # ============================================
        puts "5. ИНСТРУКЦИИ ПО УХОДУ"
        puts "-" * 80
        
        care_header = modal.css('.pipf-product-details-modal__care-header').first
        if care_header
          care_section = care_header.parent || care_header.next_element
          care_instructions = []
          
          # Заголовок секции ухода
          care_section_title = care_section.css('.pipf-product-details-modal__header').first&.text&.strip
          care_instructions << care_section_title if care_section_title.present?
          
          # Инструкции
          care_section.css('.pipf-product-details-modal__label').each do |label|
            text = label.text.strip
            care_instructions << text if text.present?
          end
          
          attributes[:care_instructions] = care_instructions.join("\n")
          attributes[:care_instructions_list] = care_instructions
          
          puts "  ✓ Инструкции по уходу: #{care_instructions.length} пунктов"
          care_instructions.each_with_index do |inst, idx|
            puts "    #{idx + 1}. #{inst}"
          end
        else
          puts "  ✗ Инструкции по уходу: Нет"
        end
        puts ""
        
        # ============================================
        # 6. БЕЗОПАСНОСТЬ
        # ============================================
        puts "6. БЕЗОПАСНОСТЬ"
        puts "-" * 80
        
        safety_section = modal.css('h3').find { |h| 
          h.text.to_s.include?('Bezpieczeństwo') || 
          h.text.to_s.include?('Безопасность') ||
          h.text.to_s.include?('Safety')
        }
        
        if safety_section
          safety_info = []
          safety_section.parent.css('.pipf-product-details-modal__paragraph').each do |p|
            text = p.text.strip
            safety_info << text if text.present?
          end
          
          attributes[:safety_info] = safety_info.join("\n\n")
          attributes[:safety_info_list] = safety_info
          
          puts "  ✓ Безопасность: #{safety_info.length} пунктов"
          safety_info.each_with_index do |info, idx|
            puts "    #{idx + 1}. #{info[0..150]}..."
          end
        else
          puts "  ✗ Безопасность: Нет"
        end
        puts ""
        
        # ============================================
        # 7. ПОЛЕЗНО ЗНАТЬ
        # ============================================
        puts "7. ПОЛЕЗНО ЗНАТЬ"
        puts "-" * 80
        
        good_to_know_header = modal.css('h3').find { |h| 
          h.text.to_s.include?('Dobrze wiedzieć') || 
          h.text.to_s.include?('Полезно знать') ||
          h.text.to_s.include?('Good to know')
        }
        
        if good_to_know_header
          good_to_know = []
          good_to_know_header.parent.css('.pipf-product-details-modal__paragraph').each do |p|
            text = p.text.strip
            good_to_know << text if text.present?
          end
          
          attributes[:good_to_know] = good_to_know.join("\n\n")
          attributes[:good_to_know_list] = good_to_know
          
          puts "  ✓ Полезно знать: #{good_to_know.length} пунктов"
          good_to_know.each_with_index do |info, idx|
            puts "    #{idx + 1}. #{info}"
          end
        else
          puts "  ✗ Полезно знать: Нет"
        end
        puts ""
        
        # ============================================
        # 8. ДОКУМЕНТЫ
        # ============================================
        puts "8. ДОКУМЕНТЫ"
        puts "-" * 80
        
        documents = modal.css('.pipf-product-details-modal__document-link')
        if documents.any?
          doc_list = []
          documents.each do |doc_link|
            href = doc_link['href']
            text = doc_link.text.strip
            doc_list << { title: text, url: href }
          end
          
          attributes[:assembly_documents] = doc_list.map { |d| d[:url] }.join("\n")
          attributes[:assembly_documents_list] = doc_list
          
          puts "  ✓ Документы: #{doc_list.length} файлов"
          doc_list.each_with_index do |doc, idx|
            puts "    #{idx + 1}. #{doc[:title]}: #{doc[:url]}"
          end
        else
          puts "  ✗ Документы: Нет"
        end
        puts ""
      end
      
      # ============================================
      # ИТОГОВЫЙ СПИСОК ВСЕХ АТРИБУТОВ
      # ============================================
      puts "=" * 80
      puts "ИТОГОВЫЙ СПИСОК ВСЕХ АТРИБУТОВ ПРОДУКТА"
      puts "=" * 80
      puts ""
      
      all_attributes = {
        'Базовые атрибуты' => [
          'name (Название)',
          'sku (Артикул)',
          'price (Цена)',
          'weight (Вес)',
          'dimensions (Размеры)',
          'collection (Коллекция)',
          'images (Изображения)',
          'url (URL продукта)'
        ],
        'Описание' => [
          'description (Полное описание)',
          'description_paragraphs (Параграфы описания)',
          'short_description (Краткое описание)'
        ],
        'Дополнительная информация' => [
          'designer (Дизайнер)',
          'materials (Материалы)',
          'materials_list (Список материалов)',
          'care_instructions (Инструкции по уходу)',
          'care_instructions_list (Список инструкций по уходу)',
          'safety_info (Информация о безопасности)',
          'safety_info_list (Список информации о безопасности)',
          'good_to_know (Полезно знать)',
          'good_to_know_list (Список "Полезно знать")',
          'assembly_documents (Документы по сборке)',
          'assembly_documents_list (Список документов)'
        ]
      }
      
      all_attributes.each do |category, attrs|
        puts "#{category}:"
        attrs.each do |attr|
          key = attr.split(' ').first.to_sym
          status = attributes[key].present? ? '✓' : '✗'
          puts "  #{status} #{attr}"
        end
        puts ""
      end
      
      # Статистика
      total_attrs = all_attributes.values.flatten.length
      filled_attrs = all_attributes.values.flatten.count { |attr|
        key = attr.split(' ').first.to_sym
        attributes[key].present?
      }
      
      puts "=" * 80
      puts "СТАТИСТИКА"
      puts "=" * 80
      puts "Всего атрибутов: #{total_attrs}"
      puts "Заполнено: #{filled_attrs}"
      puts "Процент заполнения: #{(filled_attrs.to_f / total_attrs * 100).round(1)}%"
      puts ""
      
      # Сохраняем в JSON для дальнейшего использования
      json_file = Rails.root.join('tmp', "product_#{product_id}_attributes.json")
      FileUtils.mkdir_p(File.dirname(json_file))
      File.write(json_file, JSON.pretty_generate(attributes))
      puts "Данные сохранены в: #{json_file}"
      puts ""
      
    rescue => e
      puts "ОШИБКА: #{e.class} - #{e.message}"
      puts e.backtrace.first(10).join("\n")
    end
  end
end

