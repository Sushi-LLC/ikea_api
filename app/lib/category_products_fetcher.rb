# Парсер продуктов со страницы категории IKEA
require 'nokogiri'
require 'net/http'
require 'uri'
require 'json'

class CategoryProductsFetcher
  def self.fetch(category_url, offset: 0, limit: 50)
    new.fetch(category_url, offset: offset, limit: limit)
  end
  
  def fetch(category_url, offset: 0, limit: 50)
    full_url = category_url.start_with?('http') ? category_url : "https://www.ikea.com#{category_url}"
    
    # Добавляем параметры пагинации к URL
    uri = URI.parse(full_url)
    uri.query = URI.encode_www_form({
      'page' => (offset / limit) + 1,
      'per_page' => limit
    })
    
    html = fetch_with_proxy(uri.to_s)
    return [] unless html
    
    doc = Nokogiri::HTML(html)
    products = []
    
    Rails.logger.info "CategoryProductsFetcher: Parsing HTML for URL: #{full_url}"
    Rails.logger.debug "CategoryProductsFetcher: HTML size: #{html.length} bytes"
    
    # Стратегия 1: Ищем JSON данные о продуктах в скриптах страницы
    # IKEA обычно хранит данные продуктов в window.__INITIAL_STATE__ или подобных структурах
    doc.css('script').each do |script|
      script_text = script.text
      
      # Ищем JSON-LD данные о продуктах
      if script_text.include?('"@type":"Product"') || script_text.include?('application/ld+json')
        begin
          json_data = JSON.parse(script_text)
          if json_data.is_a?(Array)
            json_data.each do |item|
              if item['@type'] == 'Product'
                products << extract_product_from_json_ld(item)
              end
            end
          elsif json_data['@type'] == 'Product'
            products << extract_product_from_json_ld(json_data)
          end
        rescue JSON::ParserError
          # Пробуем найти JSON в тексте скрипта
          if script_text.match(/window\.__INITIAL_STATE__\s*=\s*({.+?});/m)
            json_str = $1
            begin
              data = JSON.parse(json_str)
              found = extract_products_from_state(data)
              products.concat(found)
              Rails.logger.debug "CategoryProductsFetcher: Found #{found.length} products in __INITIAL_STATE__"
            rescue JSON::ParserError => e
              Rails.logger.debug "CategoryProductsFetcher: Failed to parse __INITIAL_STATE__: #{e.message[0..100]}"
              next
            end
          end
        end
      end
      
      # Ищем данные в data-hydration-props
      if script_text.include?('data-hydration-props') || script_text.include?('productList')
        begin
          # Пробуем извлечь JSON из различных паттернов
          if match = script_text.match(/productList.*?(\[.+?\])/m)
            json_str = match[1]
            data = JSON.parse(json_str)
            found = extract_products_from_array(data)
            products.concat(found)
            Rails.logger.debug "CategoryProductsFetcher: Found #{found.length} products in productList"
          end
        rescue JSON::ParserError, NoMethodError => e
          Rails.logger.debug "CategoryProductsFetcher: Failed to parse productList: #{e.message[0..100]}"
          next
        end
      end
      
      # НОВОЕ: Ищем данные в <script type="application/json">
      if script['type'] == 'application/json'
        begin
          json_data = JSON.parse(script_text)
          found = extract_products_from_state(json_data)
          products.concat(found)
          Rails.logger.debug "CategoryProductsFetcher: Found #{found.length} products in application/json script"
        rescue JSON::ParserError => e
          Rails.logger.debug "CategoryProductsFetcher: Failed to parse application/json script: #{e.message[0..100]}"
        end
      end
      
      # НОВОЕ: Ищем window.__IKEA_PRODUCTS__ или подобные структуры
      ['__IKEA_PRODUCTS__', '__PRODUCTS__', '__PRODUCT_LIST__', 'productData', 'productsData'].each do |var_name|
        if script_text.include?(var_name)
          match = script_text.match(/#{Regexp.escape(var_name)}\s*=\s*({.+?});/m)
          if match
            begin
              json_str = match[1]
              data = JSON.parse(json_str)
              found = extract_products_from_state(data)
              products.concat(found)
              Rails.logger.debug "CategoryProductsFetcher: Found #{found.length} products in #{var_name}"
            rescue JSON::ParserError => e
              Rails.logger.debug "CategoryProductsFetcher: Failed to parse #{var_name}: #{e.message[0..100]}"
            end
          end
        end
      end
    end
    
    # Стратегия 2: Если не нашли в JSON, пробуем парсить HTML структуру
    if products.empty?
      Rails.logger.debug "CategoryProductsFetcher: No products found in JSON, trying HTML parsing"
      products = extract_products_from_html(doc)
    else
      Rails.logger.info "CategoryProductsFetcher: Found #{products.length} products in JSON data"
    end
    
    # Стратегия 3: НОВОЕ - Ищем продукты в data-атрибутах элементов
    if products.empty?
      Rails.logger.debug "CategoryProductsFetcher: No products found in HTML structure, trying data attributes"
      products = extract_products_from_data_attributes(doc)
    end
    
    # Стратегия 4: НОВОЕ - Ищем ссылки на продукты (паттерн /pl/pl/p/products/...)
    if products.empty?
      Rails.logger.debug "CategoryProductsFetcher: No products found, trying product links"
      products = extract_products_from_links(doc)
    end
    
    unique_products = products.uniq { |p| p['sku'] || p[:sku] || p['id'] || p[:id] }
    Rails.logger.info "CategoryProductsFetcher: Total unique products found: #{unique_products.length}"
    
    unique_products
  end
  
  private
  
  def fetch_with_proxy(url)
    ProxyRotator.with_proxy_retry do |proxy_options|
      uri = URI.parse(url)
      
      if proxy_options && proxy_options[:http_proxyaddr]
        http = Net::HTTP.new(uri.host, uri.port,
                             proxy_options[:http_proxyaddr],
                             proxy_options[:http_proxyport],
                             proxy_options[:http_proxyuser],
                             proxy_options[:http_proxypass])
      else
        http = Net::HTTP.new(uri.host, uri.port)
      end
      
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 30
      
      request = Net::HTTP::Get.new(uri.path + (uri.query ? "?#{uri.query}" : ''))
      request['User-Agent'] = ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      request['Accept-Language'] = 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7'
      
      response = http.request(request)
      
      if response.is_a?(Net::HTTPSuccess)
        response.body
      else
        raise StandardError, "HTTP error: #{response.code} #{response.message}"
      end
    end
  end
  
  def extract_product_from_json_ld(json_ld)
    sku = json_ld['mpn'] || json_ld['sku'] || json_ld[:mpn] || json_ld[:sku]
    return nil unless sku.present?
    
    {
      'id' => sku,
      'sku' => sku,
      'name' => json_ld['name'] || json_ld[:name],
      'itemNo' => sku,
      'itemNoGlobal' => sku,
      'pipUrl' => json_ld['url'] || json_ld[:url] || json_ld.dig('offers', 'url') || json_ld.dig(:offers, :url),
      'typeName' => json_ld['name'] || json_ld[:name],
      'salesPrice' => {
        'numeral' => json_ld.dig('offers', 'price') || json_ld.dig(:offers, :price)
      },
      'imageUrl' => Array(json_ld['image'] || json_ld[:image]).first,
      'images' => Array(json_ld['image'] || json_ld[:image]).compact
    }
  end
  
  def extract_products_from_state(state)
    products = []
    # Рекурсивно ищем продукты в структуре state
    find_products_in_hash(state, products)
    products
  end
  
  def find_products_in_hash(hash, products)
    return unless hash.is_a?(Hash) || hash.is_a?(Array)
    
    if hash.is_a?(Hash)
      if hash['type'] == 'PRODUCT' || hash['@type'] == 'Product'
        products << hash
      else
        hash.each_value { |v| find_products_in_hash(v, products) }
      end
    elsif hash.is_a?(Array)
      hash.each { |item| find_products_in_hash(item, products) }
    end
  end
  
  def extract_products_from_array(array)
    return [] unless array.is_a?(Array)
    
    array.select { |item| item.is_a?(Hash) && (item['type'] == 'PRODUCT' || item['@type'] == 'Product') }
  end
  
  def extract_products_from_html(doc)
    products = []
    
    # Ищем продукты в HTML структуре IKEA
    # Расширенный список селекторов для поиска продуктов
    selectors = [
      '[data-product-id]',
      '[data-item-no]',
      '[data-sku]',
      '[data-item-number]',
      '.pip-product-compact',
      '.product-compact',
      '.product-item',
      '[data-testid*="product"]',
      '.plp-product-list-item',
      'article[data-product-id]'
    ]
    
    doc.css(selectors.join(', ')).each do |product_element|
      product_id = product_element['data-product-id'] || 
                   product_element['data-item-no'] ||
                   product_element['data-sku'] ||
                   product_element['data-item-number'] ||
                   product_element['data-testid']&.gsub(/[^0-9]/, '')
      
      next unless product_id.present?
      
      product = {}
      
      product['id'] = product_id
      product['sku'] = product_id
      
      # Название - расширенный поиск
      name_elem = product_element.css(
        '.pip-product-compact__title, .product-title, h2, h3, [data-testid*="title"], .product-name, .plp-product-title'
      ).first
      name = name_elem&.text&.strip
      product['name'] = name
      product['typeName'] = name
      
      # Цена - расширенный поиск (ОБЯЗАТЕЛЬНОЕ ПОЛЕ)
      price_elem = product_element.css(
        '.pip-price, .product-price, [data-price], [data-testid*="price"], .plp-product-price, .price, [data-testid="price"]'
      ).first
      if price_elem
        price_text = price_elem.text.strip.gsub(/[^\d,.]/, '').gsub(',', '.')
        if price_text.present?
          product['salesPrice'] = { 'numeral' => price_text.to_f }
          product['price'] = price_text.to_f
        end
      else
        # Пробуем найти цену в data-атрибутах
        price_attr = product_element['data-price'] || product_element['data-sales-price']
        if price_attr.present?
          price_value = price_attr.to_s.gsub(/[^\d,.]/, '').gsub(',', '.').to_f
          if price_value > 0
            product['salesPrice'] = { 'numeral' => price_value }
            product['price'] = price_value
          end
        end
      end
      
      # URL - расширенный поиск
      link_elem = product_element.css('a[href*="/products/"], a[href*="/p/"]').first
      if link_elem
        href = link_elem['href']
        product['pipUrl'] = href.start_with?('http') ? href : "https://www.ikea.com#{href}"
      end
      
      # Изображение - расширенный поиск
      img_elem = product_element.css('img[src*="ikea"], img[data-src*="ikea"], [data-testid*="image"] img').first
      image_url = img_elem['src'] || img_elem['data-src'] || img_elem['data-lazy-src'] if img_elem
      product['imageUrl'] = image_url
      product['images'] = [image_url].compact if image_url
      
      # Количество/наличие - расширенный поиск (ОБЯЗАТЕЛЬНОЕ ПОЛЕ)
      quantity_elem = product_element.css(
        '[data-stock], [data-quantity], [data-availability], .stock, .availability, [data-testid*="stock"], [data-testid*="availability"]'
      ).first
      
      if quantity_elem
        # Пробуем извлечь из data-атрибутов
        quantity_attr = quantity_elem['data-stock'] || quantity_elem['data-quantity'] || quantity_elem['data-availability']
        if quantity_attr.present?
          quantity_value = quantity_attr.to_s.gsub(/[^\d]/, '').to_i
          if quantity_value > 0
            product['quantity'] = quantity_value
            product['availability'] = [{ 'quantity' => quantity_value }]
          end
        else
          # Пробуем извлечь из текста
          quantity_text = quantity_elem.text.strip
          if quantity_text.match?(/\d+/)
            quantity_value = quantity_text.gsub(/[^\d]/, '').to_i
            if quantity_value > 0
              product['quantity'] = quantity_value
              product['availability'] = [{ 'quantity' => quantity_value }]
            end
          end
        end
      end
      
      # Если количество не найдено, пробуем определить по статусу наличия
      if product['quantity'].blank?
        in_stock_elem = product_element.css('[data-in-stock], .in-stock, [class*="available"], [class*="stock"]').first
        if in_stock_elem
          stock_text = in_stock_elem.text.downcase || in_stock_elem['class'].to_s.downcase
          if stock_text.include?('dostępn') || stock_text.include?('in stock') || stock_text.include?('available')
            product['quantity'] = 999 # Высокий запас
            product['availability'] = [{ 'status' => 'HIGH_IN_STOCK', 'quantity' => 999 }]
          elsif stock_text.include?('brak') || stock_text.include?('out of stock') || stock_text.include?('unavailable')
            product['quantity'] = 0
            product['availability'] = [{ 'status' => 'OUT_OF_STOCK', 'quantity' => 0 }]
          end
        end
      end
      
      products << product if product['id'].present?
    end
    
    products
  end
  
  # НОВОЕ: Извлечение продуктов из data-атрибутов
  def extract_products_from_data_attributes(doc)
    products = []
    
    # Ищем элементы с data-атрибутами, содержащими информацию о продуктах
    doc.css('[data-product], [data-item], [data-product-data]').each do |element|
      # Пробуем извлечь JSON из data-атрибутов
      ['data-product', 'data-item', 'data-product-data', 'data-product-info'].each do |attr|
        json_str = element[attr]
        next unless json_str.present?
        
        begin
          data = JSON.parse(json_str)
          if data.is_a?(Hash) && (data['id'] || data['sku'] || data['itemNo'])
            product = {
              'id' => data['id'] || data['sku'] || data['itemNo'],
              'sku' => data['sku'] || data['id'] || data['itemNo'],
              'name' => data['name'] || data['title'],
              'itemNo' => data['itemNo'] || data['id'],
              'pipUrl' => data['url'] || data['href'],
              'salesPrice' => data['price'] ? { 'numeral' => data['price'] } : nil,
              'imageUrl' => data['image'] || data['imageUrl']
            }
            products << product if product['id'].present?
          end
        rescue JSON::ParserError
          next
        end
      end
    end
    
    products
  end
  
  # НОВОЕ: Извлечение продуктов из ссылок на страницы продуктов
  def extract_products_from_links(doc)
    products = []
    
    # Ищем ссылки на страницы продуктов (паттерн /pl/pl/p/products/... или /pl/pl/products/...)
    doc.css('a[href*="/products/"], a[href*="/p/products/"]').each do |link|
      href = link['href']
      next unless href.present?
      
      # Извлекаем SKU из URL (обычно в конце URL)
      # Пример: /pl/pl/p/products/hemnes-00369474/
      match = href.match(%r{/products/([^/]+)/?$})
      if match
        sku = match[1]
        # Пробуем извлечь числовой ID из SKU
        item_no = sku.match(/(\d+)$/)&.[](1)
        
        product = {
          'id' => item_no || sku,
          'sku' => item_no || sku,
          'itemNo' => item_no,
          'name' => link.text.strip,
          'pipUrl' => href.start_with?('http') ? href : "https://www.ikea.com#{href}"
        }
        
        # Пробуем найти цену рядом со ссылкой
        parent = link.parent || link
        price_elem = parent.css('.price, [data-price], .product-price').first
        if price_elem
          price_text = price_elem.text.strip.gsub(/[^\d,.]/, '').gsub(',', '.')
          product['salesPrice'] = { 'numeral' => price_text.to_f } if price_text.present?
        end
        
        products << product if product['id'].present?
      end
    end
    
    products
  end
end

