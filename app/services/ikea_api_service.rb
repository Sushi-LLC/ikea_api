# Сервис для работы с API IKEA
require 'httparty'

class IkeaApiService
  include HTTParty
  
  SEARCH_URL = 'https://sik.search.blue.cdtapps.com/pl/pl/search?c=listaf&v=20241114'
  CATEGORIES_URL = 'https://www.ikea.com/pl/pl/meta-data/navigation/catalog-products-slim.json'
  AVAILABILITY_URL = 'https://api.salesitem.ingka.com/availabilities/ru/pl'
  PAGE_SIZE = 50

  # Поиск товаров по категории
  def self.search_products_by_category(category_id, offset: 0, limit: PAGE_SIZE)
    ProxyRotator.with_proxy_retry do |proxy_options|
      response = post(
        SEARCH_URL,
        body: {
          searchParameters: {
            input: category_id,
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
          'Connection' => 'keep-alive',
          'Referer' => 'https://www.ikea.com/pl/pl/',
          'Origin' => 'https://www.ikea.com'
        },
        timeout: 30,
        **(proxy_options || {})
      )

      unless response.success?
        Rails.logger.error "IkeaApiService.fetch_categories failed: HTTP #{response.code} - #{response.message}"
        Rails.logger.error "Response body: #{response.body[0..500]}" if response.body
        return nil
      end

      body = response.body
      # HTTParty автоматически распаковывает gzip, но проверим на всякий случай
      if body.present?
        begin
          JSON.parse(body)
        rescue JSON::ParserError => e
          Rails.logger.error "IkeaApiService.fetch_categories JSON parse error: #{e.message}"
          Rails.logger.error "Response body preview: #{body[0..200]}"
          nil
        end
      end
    rescue => e
      Rails.logger.error "IkeaApiService.fetch_categories error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
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
    return [] unless response.success?

    items = response.dig('results', 0, 'items') || []
    items.select { |item| item['type'] == 'PRODUCT' }
        .map { |item| item['product'] }
  end

  def self.parse_availability_response(response)
    return {} unless response.success?

    availabilities = response.dig('availabilities') || []
    result = {}
    
    availabilities.each do |avail|
      item_no = avail['itemNo']
      buying_option = avail.dig('buyingOption', 'homeDelivery', 'availability')
      
      result[item_no] = {
        quantity: buying_option&.dig('quantity') || 0,
        is_parcel: buying_option&.dig('parcel') || false
      }
    end
    
    result
  end
end


