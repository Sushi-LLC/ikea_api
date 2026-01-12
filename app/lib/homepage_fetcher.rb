# Парсер главной страницы IKEA через scrape.do
# Извлекает "Хиты продаж" и "Популярные категории"
require 'nokogiri'
require 'net/http'
require 'uri'
require 'json'

class HomepageFetcher
  MAIN_PAGE_URL = 'https://www.ikea.com/pl/pl/'
  
  def self.fetch
    new.fetch
  end
  
  def fetch
    Rails.logger.info "HomepageFetcher: Fetching main page via scrape.do"
    
    result = {
      bestseller_skus: [],
      bestseller_urls: {}, # URL для каждого SKU
      bestseller_names: {}, # Названия продуктов для каждого SKU
      popular_category_ids: [],
      popular_category_urls: {} # URL и названия для каждой категории
    }
    
    begin
      # Получаем HTML через scrape.do API
      html = fetch_via_scrape_do(MAIN_PAGE_URL)
      
      if html && html.length > 10000
        Rails.logger.info "HomepageFetcher: HTML received, length: #{html.length}"
        doc = Nokogiri::HTML(html)
        
        # Извлекаем хиты продаж
        result[:bestseller_skus] = extract_bestsellers(doc)
        result[:bestseller_urls] = @product_urls || {}
        result[:bestseller_names] = @product_names || {}
        Rails.logger.info "HomepageFetcher: Found #{result[:bestseller_skus].length} bestseller SKUs with #{result[:bestseller_urls].length} URLs"
        
        # Извлекаем популярные категории
        result[:popular_category_ids] = extract_popular_categories(doc)
        result[:popular_category_urls] = @category_urls || {}
        Rails.logger.info "HomepageFetcher: Found #{result[:popular_category_ids].length} popular category IDs"
      else
        Rails.logger.warn "HomepageFetcher: HTML too short or empty (#{html&.length || 0} chars)"
      end
    rescue => e
      Rails.logger.error "HomepageFetcher: Error fetching homepage: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end
    
    result
  end
  
  private
  
  def fetch_via_scrape_do(url)
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
      'render' => 'true', # Для JavaScript рендеринга
      'wait' => '5000' # Ждем 5 секунд для загрузки JS
    }
    
    request_uri = "#{uri.path}?#{URI.encode_www_form(params)}"
    request = Net::HTTP::Get.new(request_uri)
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      Rails.logger.error "HomepageFetcher: Scrape.do API error: HTTP #{response.code} - #{response.message}"
      nil
    end
  end
  
  def extract_bestsellers(doc)
    skus = []
    product_urls = {} # Сохраняем URL для каждого SKU
    product_names = {} # Сохраняем названия для каждого SKU
    
    # Ищем секцию "Хиты продаж" / "Bestsellers" / "Hity"
    bestseller_section = find_section_by_title(doc, [
      'Хиты продаж',
      'Bestsellers',
      'Hity',
      'Hity sprzedaży',
      'Najpopularniejsze produkty',
      'Popular products'
    ])
    
    if bestseller_section
      Rails.logger.info "HomepageFetcher: Found bestsellers section"
      
      # Ищем продукты в секции
      bestseller_section.css('[data-product-id], [data-sku], [data-item-no], .product-item, .pip-product-compact').each do |elem|
        sku = elem['data-product-id'] || 
              elem['data-sku'] || 
              elem['data-item-no'] ||
              elem['data-item-no-global']
        
        if sku.present?
          normalized_sku = normalize_sku(sku)
          skus << normalized_sku
          
          # Пробуем найти название продукта
          product_name = elem['data-product-name'] ||
                        elem['data-name'] ||
                        elem['aria-label'] ||
                        elem.text.strip.presence ||
                        elem.ancestors('a').first&.text&.strip
          
          # Пробуем найти URL в родительской ссылке
          link = elem.ancestors('a').first
          if link && link['href']
            href = link['href']
            full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
            if full_url.include?('/p/')
              product_urls[normalized_sku] = full_url
              product_names[normalized_sku] = product_name if product_name
            end
          elsif product_name
            product_names[normalized_sku] = product_name
          end
        end
      end
      
      # Ищем в ссылках на продукты
      bestseller_section.css('a[href*="/p/"]').each do |link|
        href = link['href']
        next unless href
        
        # Извлекаем название продукта
        product_name = link.text.strip.presence ||
                      link['aria-label'] ||
                      link['title'] ||
                      link.css('img').first&.[]('alt')
        
        # Формат: /pl/pl/p/{product-slug}-{sku}/ или https://www.ikea.com/pl/pl/p/{product-slug}-{sku}/
        if match = href.match(%r{/p/([^/]+)/?})
          product_slug = match[1]
          # Извлекаем SKU из slug (обычно в конце после последнего дефиса)
          # Формат: product-name-{sku} (SKU обычно 8 цифр)
          parts = product_slug.split('-')
          if parts.any?
            last_part = parts.last
            # Если последняя часть - это 8 цифр, это SKU
            if last_part.match(/^\d{8}$/)
              normalized_sku = normalize_sku(last_part)
              skus << normalized_sku
              full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
              product_urls[normalized_sku] = full_url
              product_names[normalized_sku] = product_name if product_name
            # Или ищем SKU в любом месте slug
            elsif sku_match = product_slug.match(/([s]?\d{6,})/)
              normalized_sku = normalize_sku(sku_match[1])
              skus << normalized_sku
              full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
              product_urls[normalized_sku] = full_url
              product_names[normalized_sku] = product_name if product_name
            end
          end
        end
      end
      
      # Ищем в data-атрибутах продуктов
      bestseller_section.css('[data-product], [data-item]').each do |elem|
        # Пробуем извлечь из data-атрибутов
        product_data = elem['data-product'] || elem['data-item']
        if product_data
          begin
            data = JSON.parse(product_data)
            extract_skus_from_json(data, skus, product_urls, product_names)
          rescue JSON::ParserError
            # Если не JSON, пробуем как строку
            if sku_match = product_data.match(/([s]?\d{6,})/)
              normalized_sku = normalize_sku(sku_match[1])
              skus << normalized_sku unless skus.include?(normalized_sku)
            end
          end
        end
      end
      
      # Ищем в JSON-LD
      bestseller_section.css('script[type="application/ld+json"]').each do |script|
        begin
          data = JSON.parse(script.text)
          extract_skus_from_json(data, skus, product_urls, product_names)
        rescue JSON::ParserError
          next
        end
      end
    else
      Rails.logger.warn "HomepageFetcher: Bestsellers section not found, searching entire page"
      
      # Если секция не найдена, ищем по всей странице
      # Ищем в data-атрибутах
      doc.css('[data-product-id], [data-sku], [data-item-no]').each do |elem|
        sku = elem['data-product-id'] || 
              elem['data-sku'] || 
              elem['data-item-no']
        
        if sku.present?
          skus << normalize_sku(sku)
        end
      end
      
      # Ищем в ссылках на продукты (первые 20 для "хитов продаж")
      doc.css('a[href*="/p/"]').first(20).each do |link|
        href = link['href']
        next unless href
        
        product_name = link.text.strip.presence ||
                      link['aria-label'] ||
                      link['title']
        
        if match = href.match(%r{/p/([^/]+)/?})
          product_slug = match[1]
          parts = product_slug.split('-')
          if parts.any?
            last_part = parts.last
            if last_part.match(/^\d{8}$/)
              normalized_sku = normalize_sku(last_part)
              skus << normalized_sku
              full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
              product_urls[normalized_sku] = full_url
              product_names[normalized_sku] = product_name if product_name
            elsif sku_match = product_slug.match(/([s]?\d{6,})/)
              normalized_sku = normalize_sku(sku_match[1])
              skus << normalized_sku
              full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
              product_urls[normalized_sku] = full_url
              product_names[normalized_sku] = product_name if product_name
            end
          end
        end
      end
    end
    
    # Сохраняем URL и названия в результат
    @product_urls = product_urls
    @product_names = product_names
    
    initial_count = skus.length
    Rails.logger.info "HomepageFetcher: Found #{initial_count} products from section/fallback"
    
    # Ищем в data-hydration-props и скриптах (более агрессивный поиск)
    doc.css('script').each do |script|
      script_text = script.text
      # Расширяем поиск - ищем не только по ключевым словам, но и по структурам данных
      if script_text.include?('bestseller') || 
         script_text.include?('bestsellers') || 
         script_text.include?('hity') ||
         script_text.include?('product') ||
         script_text.include?('itemNo') ||
         script_text.include?('productId') ||
         script_text.match(%r{/p/[^"'\s]+-\d{6,}/})
        extract_skus_from_script(script_text, skus, product_urls, product_names)
      end
    end
    
    # Ищем в data-hydration-props (React/Next.js)
    doc.css('[data-hydration], [data-reactroot], [data-nextjs]').each do |elem|
      # Пробуем найти JSON данные
      hydration_data = elem['data-hydration'] || elem.text
      if hydration_data.present?
        begin
          data = JSON.parse(hydration_data)
          extract_skus_from_json(data, skus, product_urls, product_names)
        rescue JSON::ParserError
          # Не JSON, пропускаем
        end
      end
    end
    
    # Ищем в window.__NEXT_DATA__ или других глобальных переменных (в тексте скриптов)
    doc.css('script').each do |script|
      script_text = script.text
      # Ищем структуры типа window.__NEXT_DATA__, window.__INITIAL_STATE__ и т.д.
      if script_text.include?('__NEXT_DATA__') || 
         script_text.include?('__INITIAL_STATE__') ||
         script_text.include?('window.') && script_text.include?('product')
        # Извлекаем JSON из скрипта
        if match = script_text.match(/(?:__NEXT_DATA__|__INITIAL_STATE__)\s*=\s*({.+?});/m)
          begin
            data = JSON.parse(match[1])
            extract_skus_from_json(data, skus, product_urls, product_names)
          rescue JSON::ParserError
            # Пробуем найти SKU напрямую в тексте
            script_text.scan(/(\d{8})/).each do |match|
              sku = normalize_sku(match[0])
              skus << sku unless skus.include?(sku)
            end
          end
        end
      end
    end
    
    final_count = skus.uniq.length
    Rails.logger.info "HomepageFetcher: Total products found after script parsing: #{final_count} (added #{final_count - initial_count} from scripts)"
    
    # Обновляем URL и названия после парсинга скриптов
    @product_urls = product_urls
    @product_names = product_names
    
    skus.uniq.compact
  end
  
  def extract_popular_categories(doc)
    category_ids = []
    category_urls = {} # Сохраняем URL и названия для каждого ID
    
    # Ищем секцию "Популярные категории" / "Popular categories" / "Popularne kategorie"
    popular_section = find_section_by_title(doc, [
      'Популярные категории',
      'Popular categories',
      'Popularne kategorie',
      'Popularne',
      'Kategorie',
      'Najpopularniejsze kategorie',
      'Shop by room',
      'Shop by category',
      'Kupuj według',
      'Kupuj wedlug',
      'Kategorie produktów',
      'Product categories'
    ])
    
    # Также ищем по классам и data-атрибутам
    unless popular_section
      popular_section = doc.css('[class*="popular"], [class*="category"], [data-section*="popular"], [data-section*="category"]').first
      if popular_section
        # Ищем родительский контейнер
        popular_section = popular_section.ancestors('[class*="section"], [class*="block"], [class*="container"], [class*="grid"]').first || popular_section
      end
    end
    
    if popular_section
      Rails.logger.info "HomepageFetcher: Found popular categories section"
      
      # Ищем категории в секции
      popular_section.css('a[href*="/cat/"]').each do |link|
        href = link['href']
        next unless href
        
        # Извлекаем название категории из ссылки или текста
        category_name = link.text.strip.presence || 
                       link['aria-label'] || 
                       link['title'] ||
                       link.css('img').first&.[]('alt') ||
                       link.css('[class*="name"], [class*="title"]').first&.text&.strip
        
        # Формат: /pl/pl/cat/{category-slug}/ или /pl/pl/cat/{category-id}/
        if match = href.match(%r{/cat/([^/]+)/?})
          category_slug = match[1]
          
          if category_slug.match(/^\d+$/)
            # Если это числовой ID, используем его
            category_ids << category_slug unless category_ids.include?(category_slug)
            full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
            category_urls[category_slug] = { url: full_url, name: category_name } if category_name || full_url
          else
            # Для slug сохраняем полный URL для поиска по URL (приоритет)
            full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
            category_ids << full_url unless category_ids.include?(full_url)
            category_urls[full_url] = { url: full_url, name: category_name } if category_name || full_url
          end
        end
      end
      
      # Ищем в data-атрибутах внутри секции
      popular_section.css('[data-category-id], [data-categoryId], [data-category], [data-id]').each do |elem|
        category_id = elem['data-category-id'] || 
                      elem['data-categoryId'] ||
                      elem['data-category'] ||
                      elem['data-id']
        
        if category_id.present?
          # Добавляем только числовые ID (UUID не находятся в БД по ikea_id)
          if category_id.match(/^\d+$/)
            category_ids << category_id unless category_ids.include?(category_id)
            # Пробуем найти название
            category_name = elem['data-category-name'] || 
                           elem['data-name'] ||
                           elem.text.strip.presence ||
                           elem.ancestors('a').first&.text&.strip
            category_urls[category_id] = { name: category_name } if category_name
          end
        end
      end
    end
    
    # Если секция не найдена или найдено мало категорий, ищем по всей странице
    if !popular_section || category_ids.length < 3
      Rails.logger.warn "HomepageFetcher: Popular categories section not found or too few categories (#{category_ids.length}), searching entire page"
      
      # Ищем по всей странице (первые 50 ссылок на категории)
      doc.css('a[href*="/cat/"]').first(50).each do |link|
        href = link['href']
        next unless href
        
        # Пропускаем ссылки на подкатегории (содержат более одного /cat/)
        next if href.scan(%r{/cat/}).length > 1
        
        category_name = link.text.strip.presence || 
                       link['aria-label'] || 
                       link['title'] ||
                       link.css('img').first&.[]('alt')
        
        if match = href.match(%r{/cat/([^/]+)/?})
          category_slug = match[1]
          
          # Пропускаем UUID
          next if category_slug.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
          
          if category_slug.match(/^\d+$/)
            unless category_ids.include?(category_slug)
              category_ids << category_slug
              full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
              category_urls[category_slug] = { url: full_url, name: category_name } if category_name || full_url
            end
          else
            full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
            unless category_ids.include?(full_url)
              category_ids << full_url
              category_urls[full_url] = { url: full_url, name: category_name } if category_name || full_url
            end
          end
        end
      end
    end
    
    # Ищем в скриптах и JSON-LD
    doc.css('script[type="application/ld+json"], script').each do |script|
      script_text = script.text
      if script_text.include?('category') || script_text.include?('kategorie') || script_text.include?('popular')
        extract_category_ids_from_script(script_text, category_ids, category_urls)
      end
    end
    
    # Сохраняем URL и названия в результат
    @category_urls = category_urls
    
    Rails.logger.info "HomepageFetcher: Extracted #{category_ids.length} popular category IDs"
    
    category_ids.uniq.compact
  end
  
  def find_section_by_title(doc, titles)
    # Ищем заголовок с нужным текстом
    titles.each do |title|
      # Ищем h1, h2, h3, h4 с текстом (case insensitive)
      heading = doc.css('h1, h2, h3, h4').find do |h|
        text = h.text.to_s.downcase
        title_down = title.downcase
        text.include?(title_down) || title_down.include?(text.strip[0..50])
      end
      
      if heading
        # Возвращаем родительский контейнер секции
        section = heading.parent
        section ||= heading.ancestors('[class*="section"], [class*="block"], [class*="container"], [class*="grid"], [class*="row"]').first
        if section
          Rails.logger.info "HomepageFetcher: Found section by heading '#{title}'"
          return section
        end
      end
      
      # Ищем по data-атрибутам и классам (case insensitive)
      title_down = title.downcase.gsub(/\s+/, '-')
      section = doc.css("[data-section*='#{title_down}'], [class*='#{title_down}'], [aria-label*='#{title.downcase}']").first
      if section
        Rails.logger.info "HomepageFetcher: Found section by attribute/class '#{title}'"
        return section
      end
    end
    
    nil
  end
  
  def normalize_sku(sku)
    # Нормализуем SKU: убираем точки, дефисы, пробелы
    # SKU может быть с буквой в начале (например, "s09521500")
    normalized = sku.to_s.strip.gsub(/[.\-\s]/, '')
    # Оставляем как есть (может быть "s09521500" или "90349326")
    normalized
  end
  
  def normalize_category_id(category_id)
    # Нормализуем ID категории
    category_id.to_s.strip
  end
  
  def extract_skus_from_json(data, skus, product_urls = {}, product_names = {})
    case data
    when Hash
      # Ищем SKU в различных полях
      sku = nil
      ['id', 'sku', 'productId', 'itemNo', 'itemNoGlobal', 'mpn'].each do |key|
        if data[key].present?
          sku = normalize_sku(data[key])
          if sku.present? && !skus.include?(sku)
            skus << sku
            
            # Сохраняем URL и название, если есть
            if data['url'] || data['href']
              url = data['url'] || data['href']
              full_url = url.start_with?('http') ? url : "https://www.ikea.com#{url}"
              product_urls[sku] = full_url if full_url.include?('/p/')
            end
            
            if data['name'] || data['title']
              product_names[sku] = data['name'] || data['title']
            end
          end
        end
      end
      
      # Рекурсивно ищем в значениях
      data.each_value { |v| extract_skus_from_json(v, skus, product_urls, product_names) }
    when Array
      data.each { |item| extract_skus_from_json(item, skus, product_urls, product_names) }
    end
  end
  
  def extract_skus_from_script(script_text, skus, product_urls = {}, product_names = {})
    # Ищем SKU в различных форматах
    # Формат: 403.411.01 или 40341101
    script_text.scan(/(\d{3}\.?\d{3}\.?\d{2,3})/) do |match|
      sku = normalize_sku(match[0])
      if sku.present? && !skus.include?(sku)
        skus << sku
      end
    end
    
    # Ищем в структурах типа "id": "403.411.01"
    script_text.scan(/["'](?:id|sku|itemNo)["']\s*:\s*["']([^"']+)["']/i) do |match|
      sku = normalize_sku(match[0])
      if sku.present? && !skus.include?(sku)
        skus << sku
      end
    end
    
    # Ищем URL продуктов в скриптах
    script_text.scan(%r{(https?://[^"'\s]+/p/[^"'\s]+)}) do |match|
      url = match[0]
      if url.include?('/p/')
        # Извлекаем SKU из URL
        if sku_match = url.match(/-(\d{8})/)
          sku = normalize_sku(sku_match[1])
          if sku.present? && !skus.include?(sku)
            skus << sku
            product_urls[sku] = url
          end
        end
      end
    end
    
    # Ищем 8-значные числа (типичный формат SKU IKEA)
    script_text.scan(/\b(\d{8})\b/) do |match|
      sku = normalize_sku(match[0])
      # Проверяем, что это не часть даты или другого числа
      if sku.present? && !skus.include?(sku) && sku.to_i > 10000000
        skus << sku
      end
    end
  end
  
  def extract_category_ids_from_json(data, category_ids, category_urls = {})
    case data
    when Hash
      # Ищем categoryId, id, category_id
      ['categoryId', 'category_id', 'id'].each do |key|
        if data[key].present?
          category_id = normalize_category_id(data[key].to_s)
          if category_id.present? && category_id.match(/^\d+$/)
            category_ids << category_id unless category_ids.include?(category_id)
            # Пробуем найти название
            if data['name'] || data['title']
              category_urls[category_id] = { name: data['name'] || data['title'] }
            end
          end
        end
      end
      
      # Ищем URL категорий
      if data['url'] && data['url'].to_s.include?('/cat/')
        url = data['url'].to_s
        category_slug = url.split('/cat/').last.split('/').first
        unless category_slug.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
          if category_slug.match(/^\d+$/)
            category_ids << category_slug unless category_ids.include?(category_slug)
            category_urls[category_slug] = { url: url, name: data['name'] || data['title'] }
          else
            category_ids << url unless category_ids.include?(url)
            category_urls[url] = { url: url, name: data['name'] || data['title'] }
          end
        end
      end
      
      # Рекурсивно ищем в значениях
      data.each_value { |v| extract_category_ids_from_json(v, category_ids, category_urls) }
    when Array
      data.each { |item| extract_category_ids_from_json(item, category_ids, category_urls) }
    end
  end
  
  def extract_category_ids_from_script(script_text, category_ids, category_urls = {})
    # Ищем JSON структуры с categoryId
    script_text.scan(/categoryId["\s:]+([^"}\s,]+)/i) do |match|
      category_id = normalize_category_id(match[0])
      if category_id.present? && category_id.match(/^\d+$/)
        category_ids << category_id unless category_ids.include?(category_id)
      end
    end
    
    # Ищем URL категорий в скриптах
    script_text.scan(%r{(https?://[^"'\s]+/cat/[^"'\s]+)}) do |match|
      url = match[0]
      if url.include?('/cat/')
        category_slug = url.split('/cat/').last.split('/').first
        unless category_slug.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
          if category_slug.match(/^\d+$/)
            category_ids << category_slug unless category_ids.include?(category_slug)
            category_urls[category_slug] = { url: url } unless category_urls[category_slug]
          else
            category_ids << url unless category_ids.include?(url)
            category_urls[url] = { url: url } unless category_urls[url]
          end
        end
      end
    end
    
    # Пробуем распарсить как JSON
    begin
      if script_text.strip.start_with?('{') || script_text.strip.start_with?('[')
        data = JSON.parse(script_text)
        extract_category_ids_from_json(data, category_ids, category_urls)
      end
    rescue JSON::ParserError
      # Не JSON, пропускаем
    end
  end
end
