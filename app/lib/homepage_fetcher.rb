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
      popular_category_ids: []
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
        Rails.logger.info "HomepageFetcher: Found #{result[:bestseller_skus].length} bestseller SKUs with #{result[:bestseller_urls].length} URLs"
        
        # Извлекаем популярные категории
        result[:popular_category_ids] = extract_popular_categories(doc)
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
          
          # Пробуем найти URL в родительской ссылке
          link = elem.ancestors('a').first
          if link && link['href']
            href = link['href']
            full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
            product_urls[normalized_sku] = full_url if full_url.include?('/p/')
          end
        end
      end
      
      # Ищем в ссылках на продукты
      bestseller_section.css('a[href*="/p/"]').each do |link|
        href = link['href']
        next unless href
        
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
            # Или ищем SKU в любом месте slug
            elsif sku_match = product_slug.match(/([s]?\d{6,})/)
              normalized_sku = normalize_sku(sku_match[1])
              skus << normalized_sku
              full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
              product_urls[normalized_sku] = full_url
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
            extract_skus_from_json(data, skus)
          rescue JSON::ParserError
            # Если не JSON, пробуем как строку
            if sku_match = product_data.match(/([s]?\d{6,})/)
              skus << normalize_sku(sku_match[1])
            end
          end
        end
      end
      
      # Ищем в JSON-LD
      bestseller_section.css('script[type="application/ld+json"]').each do |script|
        begin
          data = JSON.parse(script.text)
          extract_skus_from_json(data, skus)
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
            elsif sku_match = product_slug.match(/([s]?\d{6,})/)
              normalized_sku = normalize_sku(sku_match[1])
              skus << normalized_sku
              full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
              product_urls[normalized_sku] = full_url
            end
          end
        end
      end
    end
    
    # Сохраняем URL в результат
    @product_urls = product_urls
    
    # Ищем в data-hydration-props и скриптах
    doc.css('script').each do |script|
      script_text = script.text
      if script_text.include?('bestseller') || script_text.include?('bestsellers') || script_text.include?('hity')
        extract_skus_from_script(script_text, skus)
      end
    end
    
    skus.uniq.compact
  end
  
  def extract_popular_categories(doc)
    category_ids = []
    
    # Сначала извлекаем URL из ссылок (приоритет над UUID)
    # Ищем в ссылках на категории по всей странице (первые 30)
    doc.css('a[href*="/cat/"]').first(30).each do |link|
      href = link['href']
      next unless href
      
      # Формат: /pl/pl/cat/{category-slug}/ или /pl/pl/cat/{category-id}/
      if match = href.match(%r{/cat/([^/]+)/?})
        category_slug = match[1]
        
        if category_slug.match(/^\d+$/)
          # Если это числовой ID, используем его
          category_ids << category_slug
        else
          # Для slug сохраняем полный URL для поиска по URL (приоритет)
          # Формат: /pl/pl/cat/{slug}/
          full_url = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
          category_ids << full_url
        end
      end
    end
    
    # Затем ищем числовые ID в data-атрибутах (только не-UUID)
    doc.css('[data-category-id], [data-categoryId]').each do |elem|
      category_id = elem['data-category-id'] || 
                    elem['data-categoryId']
      
      if category_id.present?
        # Добавляем только числовые ID (UUID не находятся в БД по ikea_id)
        if category_id.match(/^\d+$/)
          category_ids << category_id
        end
      end
    end
    
    category_ids.uniq.compact
  end
  
  def find_section_by_title(doc, titles)
    # Ищем заголовок с нужным текстом
    titles.each do |title|
      # Ищем h2, h3 с текстом
      heading = doc.css('h2, h3').find { |h| h.text.to_s.include?(title) }
      if heading
        # Возвращаем родительский контейнер секции
        section = heading.parent || heading.ancestors('[class*="section"], [class*="block"], [class*="container"]').first
        return section if section
      end
      
      # Ищем по data-атрибутам
      section = doc.css("[data-section*='#{title.downcase}'], [class*='#{title.downcase}']").first
      return section if section
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
  
  def extract_skus_from_json(data, skus)
    case data
    when Hash
      # Ищем SKU в различных полях
      ['id', 'sku', 'productId', 'itemNo', 'itemNoGlobal', 'mpn'].each do |key|
        if data[key].present?
          sku = normalize_sku(data[key])
          skus << sku if sku.present?
        end
      end
      
      # Рекурсивно ищем в значениях
      data.each_value { |v| extract_skus_from_json(v, skus) }
    when Array
      data.each { |item| extract_skus_from_json(item, skus) }
    end
  end
  
  def extract_skus_from_script(script_text, skus)
    # Ищем SKU в различных форматах
    # Формат: 403.411.01 или 40341101
    script_text.scan(/(\d{3}\.?\d{3}\.?\d{2,3})/) do |match|
      sku = normalize_sku(match[0])
      skus << sku if sku.present?
    end
    
    # Ищем в структурах типа "id": "403.411.01"
    script_text.scan(/["'](?:id|sku|itemNo)["']\s*:\s*["']([^"']+)["']/i) do |match|
      sku = normalize_sku(match[0])
      skus << sku if sku.present?
    end
  end
  
  def extract_category_ids_from_json(data, category_ids)
    case data
    when Hash
      # Ищем categoryId, id, category_id
      ['categoryId', 'category_id', 'id'].each do |key|
        if data[key].present?
          category_id = normalize_category_id(data[key])
          category_ids << category_id if category_id.present?
        end
      end
      
      # Рекурсивно ищем в значениях
      data.each_value { |v| extract_category_ids_from_json(v, category_ids) }
    when Array
      data.each { |item| extract_category_ids_from_json(item, category_ids) }
    end
  end
  
  def extract_category_ids_from_script(script_text, category_ids)
    # Ищем JSON структуры с categoryId
    script_text.scan(/categoryId["\s:]+([^"}\s,]+)/i) do |match|
      category_id = normalize_category_id(match[0])
      category_ids << category_id if category_id.present?
    end
    
    # Ищем UUID категорий
    script_text.scan(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i) do |match|
      category_id = normalize_category_id(match[0])
      category_ids << category_id if category_id.present?
    end
  end
end
