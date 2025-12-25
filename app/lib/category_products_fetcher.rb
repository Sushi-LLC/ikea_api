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
    
    # Ищем JSON данные о продуктах в скриптах страницы
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
              products.concat(extract_products_from_state(data))
            rescue JSON::ParserError
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
            products.concat(extract_products_from_array(data))
          end
        rescue JSON::ParserError, NoMethodError
          next
        end
      end
    end
    
    # Если не нашли в JSON, пробуем парсить HTML структуру
    if products.empty?
      products = extract_products_from_html(doc)
    end
    
    products.uniq { |p| p['sku'] || p[:sku] || p['id'] || p[:id] }
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
    doc.css('[data-product-id], [data-item-no], .pip-product-compact, .product-compact').each do |product_element|
      product_id = product_element['data-product-id'] || 
                   product_element['data-item-no'] ||
                   product_element['data-sku']
      
      next unless product_id.present?
      
      product = {}
      
      product['id'] = product_id
      product['sku'] = product_id
      
      # Название
      name_elem = product_element.css('.pip-product-compact__title, .product-title, h2, h3').first
      name = name_elem&.text&.strip
      product['name'] = name
      product['typeName'] = name
      
      # Цена
      price_elem = product_element.css('.pip-price, .product-price, [data-price]').first
      if price_elem
        price_text = price_elem.text.strip.gsub(/[^\d,.]/, '').gsub(',', '.')
        product['salesPrice'] = { 'numeral' => price_text.to_f } if price_text.present?
      end
      
      # URL
      link_elem = product_element.css('a').first
      product['pipUrl'] = link_elem['href'] if link_elem
      
      # Изображение
      img_elem = product_element.css('img').first
      image_url = img_elem['src'] || img_elem['data-src'] if img_elem
      product['imageUrl'] = image_url
      product['images'] = [image_url].compact if image_url
      
      products << product
    end
    
    products
  end
end

