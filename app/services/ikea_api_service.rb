# Сервис для работы с API IKEA
require 'httparty'
require 'zlib'
require 'stringio'

class IkeaApiService
  include HTTParty
  
  SEARCH_URL = 'https://sik.search.blue.cdtapps.com/pl/pl/search?c=listaf&v=20241114'
  CATEGORIES_URL = 'https://www.ikea.com/pl/pl/meta-data/navigation/catalog-products-slim.json'
  AVAILABILITY_URL = 'https://api.salesitem.ingka.com/availabilities/ru/pl'
  PAGE_SIZE = 50

  # Поиск товаров по категории
  # ВАЖНО: API ожидает числовой ID категории, а не UUID
  # Если передан UUID, возвращаем пустой массив и логируем предупреждение
  def self.search_products_by_category(category_id, offset: 0, limit: PAGE_SIZE)
    # Проверяем, является ли category_id UUID (содержит дефисы)
    if category_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) || category_id.to_s.include?('/')
      Rails.logger.warn "IkeaApiService.search_products_by_category: Category ID '#{category_id}' appears to be a UUID. API expects numeric category ID. Returning empty array."
      return []
    end
    
    ProxyRotator.with_proxy_retry do |proxy_options|
      response = post(
        SEARCH_URL,
        body: {
          searchParameters: {
            input: category_id.to_s,
            type: 'CATEGORY'
          },
          zip: ENV.fetch('IKEA_ZIP', '01-106'),
          store: ENV.fetch('IKEA_STORE', '307'),
          isUserLoggedIn: false,
          components: [{
            component: 'PRIMARY_AREA',
            columns: 4,
            types: {
              main: 'PRODUCT',
              breakouts: ['PLANNER', 'LOGIN_REMINDER', 'MATTRESS_WARRANTY']
            },
            filterConfig: { 'max-num-filters': 6 },
            sort: 'RELEVANCE',
            window: { offset: offset, size: limit }
          }]
        }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
        },
        timeout: 30,
        **(proxy_options || {})
      )

      parse_search_response(response)
    end
  end

  # Получение категорий
  def self.fetch_categories
    ProxyRotator.with_proxy_retry do |proxy_options|
      response = get(
        CATEGORIES_URL,
        headers: {
          'User-Agent' => ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'),
          'Accept' => 'application/json, text/plain, */*',
          'Accept-Language' => 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept-Encoding' => 'gzip, deflate', # Убираем br (brotli), оставляем только gzip
          'Connection' => 'keep-alive',
          'Referer' => 'https://www.ikea.com/pl/pl/',
          'Origin' => 'https://www.ikea.com',
          'Sec-Fetch-Dest' => 'empty',
          'Sec-Fetch-Mode' => 'cors',
          'Sec-Fetch-Site' => 'same-origin',
          'Cache-Control' => 'no-cache',
          'Pragma' => 'no-cache'
        },
        timeout: 30,
        **(proxy_options || {})
      )

      # Проверяем на 403 и Cloudflare блокировку
      if response.code == 403
        error_msg = "HTTP #{response.code} - Cloudflare blocked"
        Rails.logger.error "IkeaApiService.fetch_categories failed: #{error_msg}"
        raise StandardError.new(error_msg)
      end

      unless response.success?
        error_msg = "HTTP #{response.code} - #{response.message}"
        Rails.logger.error "IkeaApiService.fetch_categories failed: #{error_msg}"
        raise StandardError.new(error_msg)
      end

      body = response.body
      
      # Проверяем, не является ли тело бинарными данными (gzip не распакован)
      if body.present?
        # Если это строка, но начинается с бинарных данных (gzip magic number: 1f 8b)
        if body.is_a?(String) && body.bytesize > 2 && body.bytes.first(2) == [0x1f, 0x8b]
          Rails.logger.info "IkeaApiService: Detected gzip content, decompressing..."
          begin
            # Принудительно устанавливаем бинарную кодировку для gzip данных
            body_binary = body.force_encoding('ASCII-8BIT')
            body = Zlib::GzipReader.new(StringIO.new(body_binary)).read
            Rails.logger.info "IkeaApiService: Successfully decompressed gzip content (#{body.bytesize} bytes)"
          rescue => e
            Rails.logger.error "IkeaApiService: Failed to decompress gzip: #{e.message}"
            raise StandardError.new("Failed to decompress gzip response: #{e.message}")
          end
        end
        
        begin
          JSON.parse(body)
        rescue JSON::ParserError => e
          Rails.logger.error "IkeaApiService.fetch_categories JSON parse error: #{e.message}"
          # Пытаемся определить, что это за данные
          if body.bytes.first(2) == [0x1f, 0x8b]
            Rails.logger.error "Response appears to be gzip compressed but wasn't decompressed"
          else
            Rails.logger.error "Response body preview (first 200 chars): #{body.to_s[0..200]}"
          end
          nil
        end
      else
        nil
      end
    rescue StandardError => e
      # Пробрасываем ошибку для ProxyRotator
      raise e
    rescue => e
      Rails.logger.error "IkeaApiService.fetch_categories error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      raise StandardError.new("IkeaApiService.fetch_categories failed: #{e.message}")
    end
  end

  # Проверка наличия товара
  def self.check_availability(item_nos, client_id: nil)
    return {} unless item_nos.present?
    
    item_nos_str = Array(item_nos).join(',')
    client_id ||= ENV.fetch('IKEA_CLIENT_ID', '')
    
    ProxyRotator.with_proxy_retry do |proxy_options|
      response = get(
        "#{AVAILABILITY_URL}?itemNos=#{item_nos_str}",
        headers: {
          'x-client-id' => client_id,
          'Accept' => 'application/json'
        },
        timeout: 30,
        **(proxy_options || {})
      )

      parse_availability_response(response)
    end
  end

  # Получение детальной информации о товаре
  def self.fetch_product_details(product_url)
    ProxyRotator.with_proxy_retry do |proxy_options|
      response = get(
        product_url,
        headers: {
          'User-Agent' => ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'),
          'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        },
        timeout: 30,
        **(proxy_options || {})
      )

      response.body if response.success?
    end
  end

  private

  def self.parse_search_response(response)
    unless response.success?
      Rails.logger.error "IkeaApiService.search_products_by_category: HTTP #{response.code} - #{response.message}"
      Rails.logger.error "Response body: #{response.body[0..500]}" if response.body
      return []
    end

    items = response.dig('results', 0, 'items') || []
    Rails.logger.info "IkeaApiService.search_products_by_category: Found #{items.length} total items in response"
    
    products = items.select { |item| item['type'] == 'PRODUCT' }
                   .map { |item| item['product'] }
    
    Rails.logger.info "IkeaApiService.search_products_by_category: Extracted #{products.length} products"
    products
  end

  def self.parse_availability_response(response)
    return {} unless response.success?

    # Логируем полный ответ для отладки
    Rails.logger.debug "IkeaApiService.parse_availability_response: Response body: #{response.body[0..1000]}"
    
    # Пробуем разные форматы ответа
    availabilities = response.dig('availabilities') || response.dig('data', 'availabilities') || []
    
    # Если availabilities - это массив в корне
    if availabilities.empty? && response.parsed_response.is_a?(Array)
      availabilities = response.parsed_response
    end
    
    result = {}
    
    availabilities.each do |avail|
      item_no = avail['itemNo'] || avail['item_no'] || avail[:itemNo]
      next unless item_no.present?
      
      # Пробуем разные пути к quantity
      quantity = nil
      is_parcel = false
      
      # Путь 1: buyingOption.homeDelivery.availability.quantity
      buying_option = avail.dig('buyingOption', 'homeDelivery', 'availability')
      if buying_option
        quantity = buying_option['quantity'] || buying_option[:quantity]
        is_parcel = buying_option['parcel'] || buying_option[:parcel] || false
      end
      
      # Путь 2: availability.quantity (прямо в avail)
      if quantity.nil?
        availability = avail['availability'] || avail[:availability]
        if availability.is_a?(Hash)
          quantity = availability['quantity'] || availability[:quantity]
          is_parcel = availability['parcel'] || availability[:parcel] || false
        end
      end
      
      # Путь 3: stock.quantity
      if quantity.nil?
        stock = avail['stock'] || avail[:stock]
        if stock.is_a?(Hash)
          quantity = stock['quantity'] || stock[:quantity] || stock['available'] || stock[:available]
        end
      end
      
      # Путь 4: quantity прямо в avail
      if quantity.nil?
        quantity = avail['quantity'] || avail[:quantity] || avail['availableQuantity'] || avail[:availableQuantity]
      end
      
      # Путь 5: homeDelivery.quantity
      if quantity.nil?
        home_delivery = avail['homeDelivery'] || avail[:homeDelivery]
        if home_delivery.is_a?(Hash)
          quantity = home_delivery['quantity'] || home_delivery[:quantity] || home_delivery['available'] || home_delivery[:available]
        end
      end
      
      # Безопасное преобразование quantity в число
      quantity_int = begin
        quantity.to_i
      rescue
        0
      end
      
      result[item_no.to_s] = {
        quantity: quantity_int,
        is_parcel: is_parcel
      }
      
      Rails.logger.info "IkeaApiService.parse_availability_response: Item #{item_no} - quantity: #{result[item_no.to_s][:quantity]}, is_parcel: #{is_parcel}"
    end
    
    Rails.logger.info "IkeaApiService.parse_availability_response: Parsed #{result.length} items from #{availabilities.length} availabilities"
    result
  end
end


