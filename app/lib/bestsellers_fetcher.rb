# Парсер хитов продаж IKEA
# Основан на логике из оригинального JS-парсера
# Использует поиск по всем категориям с сортировкой и извлекает топ продуктов
require 'nokogiri'
require 'net/http'
require 'uri'
require 'httparty'
require 'json'

class BestsellersFetcher
  SEARCH_URL = 'https://sik.search.blue.cdtapps.com/pl/pl/search?c=listaf&v=20241114'
  PAGE_SIZE = 50
  
  def self.fetch(limit: 1000)
    new.fetch(limit: limit)
  end
  
  def fetch(limit: 1000)
    Rails.logger.info "BestsellersFetcher: Fetching bestsellers (limit: #{limit})"
    
    # Основной подход: поиск по всем категориям с сортировкой по популярности
    # Собираем топ продуктов из разных категорий
    bestseller_skus = fetch_via_global_search(limit: limit)
    
    Rails.logger.info "BestsellersFetcher: Found #{bestseller_skus.length} bestseller SKUs"
    if bestseller_skus.any?
      Rails.logger.info "BestsellersFetcher: First 20 SKUs: #{bestseller_skus.first(20).inspect}"
    end
    bestseller_skus.uniq
  end
  
  private

  def fetch_via_global_search(limit: 1000)
    Rails.logger.info "BestsellersFetcher: Fetching via category-based approach (like JS parser)"
    
    # Основной подход: собираем топ продукты из топ категорий
    # Это аналогично тому, как работает JS-парсер - берем первые продукты из популярных категорий
    bestseller_skus = fetch_via_categories(limit: limit)
    
    # Если не получилось через категории, пробуем глобальный поиск
    if bestseller_skus.empty?
      Rails.logger.info "BestsellersFetcher: Category-based approach returned no results, trying global search"
      bestseller_skus = fetch_via_global_api_search(limit: limit)
    end
    
    bestseller_skus.first(limit)
  end
  
  def fetch_via_global_api_search(limit: 1000)
    Rails.logger.info "BestsellersFetcher: Fetching via global API search with popularity sort"
    
    bestseller_skus = []
    max_pages = [(limit.to_f / PAGE_SIZE).ceil, 20].min  # Ограничиваем до 20 страниц
    
    # Пробуем разные варианты сортировки
    sort_options = ['POPULARITY', 'BESTSELLER', 'MOST_POPULAR']
    
    sort_options.each do |sort_option|
      Rails.logger.info "BestsellersFetcher: Trying sort option: #{sort_option}"
      
      begin
        (0...max_pages).each do |page|
          break if bestseller_skus.length >= limit
          
          current_offset = page * PAGE_SIZE
          current_limit = [PAGE_SIZE, limit - bestseller_skus.length].min
          
          ProxyRotator.with_proxy_retry do |proxy_options|
            response = HTTParty.post(
              SEARCH_URL,
              body: {
                searchParameters: {
                  input: '*',
                  type: 'PRODUCT'
                },
                zip: ENV.fetch('IKEA_ZIP', '01-106'),
                store: ENV.fetch('IKEA_STORE', '307'),
                isUserLoggedIn: false,
                components: [{
                  component: 'PRIMARY_AREA',
                  columns: 4,
                  types: {
                    main: 'PRODUCT',
                    breakouts: []
                  },
                  filterConfig: { 'max-num-filters': 6 },
                  sort: sort_option,
                  window: { offset: current_offset, size: current_limit }
                }]
              }.to_json,
              headers: {
                'Content-Type' => 'application/json',
                'x-client-id' => ENV.fetch('IKEA_CLIENT_ID', ''),
                'Accept' => 'application/json'
              },
              timeout: 30,
              **(proxy_options || {})
            )
            
            if response.success?
              items = response.dig('results', 0, 'items') || []
              products = items.select { |item| item['type'] == 'PRODUCT' }
                             .map { |item| 
                               product_data = item['product']
                               sku = product_data&.dig('id') || 
                                     product_data&.dig('sku') ||
                                     product_data&.dig('itemNoGlobal') ||
                                     product_data&.dig('itemNo')
                               sku
                             }
                             .compact
              
              if products.any?
                bestseller_skus.concat(products)
                Rails.logger.info "BestsellersFetcher: Found #{products.length} products on page #{page + 1} (total: #{bestseller_skus.length})"
              else
                break
              end
            else
              Rails.logger.warn "BestsellersFetcher: API returned error: #{response.code}"
              break
            end
          end
        end
        
        if bestseller_skus.any?
          Rails.logger.info "BestsellersFetcher: Successfully fetched #{bestseller_skus.length} products with sort: #{sort_option}"
          return bestseller_skus
        end
      rescue => e
        Rails.logger.warn "BestsellersFetcher: Search API failed with sort #{sort_option}: #{e.message}"
        next
      end
    end
    
    []
  end
  
  def fetch_via_categories(limit: 1000)
    Rails.logger.info "BestsellersFetcher: Fetching bestsellers via top categories (like JS parser)"
    
    bestseller_skus = []
    products_per_category = [limit / 50, 20].max  # Берем по 20-50 продуктов из каждой категории
    
    # Получаем топ категории (с большим количеством продуктов или популярные)
    # Используем два подхода:
    # 1. Популярные категории (если есть)
    # 2. Категории с большим количеством продуктов
    
    top_categories = []
    
    # Сначала пробуем популярные категории
    popular_categories = Category.active.where(is_popular: true).limit(30)
    if popular_categories.any?
      top_categories.concat(popular_categories.to_a)
      Rails.logger.info "BestsellersFetcher: Found #{popular_categories.count} popular categories"
    end
    
    # Добавляем категории с большим количеством продуктов
    categories_with_products = Category.active
                                      .joins(:products)
                                      .group('categories.ikea_id')
                                      .having('COUNT(products.id) > ?', 5)
                                      .order('COUNT(products.id) DESC')
                                      .limit(50)
    
    # Объединяем и убираем дубликаты
    top_categories.concat(categories_with_products.to_a)
    top_categories.uniq! { |c| c.ikea_id }
    top_categories = top_categories.first(50)  # Ограничиваем до 50 категорий
    
    Rails.logger.info "BestsellersFetcher: Processing #{top_categories.length} top categories"
    
    top_categories.each do |category|
      break if bestseller_skus.length >= limit
      
      begin
        # Получаем первые продукты из категории (это и есть "хиты продаж" для категории)
        # Используем HTML парсинг как fallback, если API не работает
        products = []
        
        # Пробуем через API
        begin
          products = IkeaApiService.search_products_by_category(
            category.ikea_id,
            offset: 0,
            limit: products_per_category
          )
        rescue => api_e
          Rails.logger.debug "BestsellersFetcher: API failed for category #{category.ikea_id}, trying HTML: #{api_e.message}"
        end
        
        # Если API не сработал и есть URL категории, пробуем HTML парсинг
        if products.empty? && category.url.present?
          begin
            products_data = CategoryProductsFetcher.fetch(
              category.url,
              offset: 0,
              limit: products_per_category
            )
            products = products_data.map(&:with_indifferent_access)
          rescue => html_e
            Rails.logger.debug "BestsellersFetcher: HTML parsing also failed for category #{category.ikea_id}: #{html_e.message}"
          end
        end
        
        if products.any?
          skus = products.map { |p| 
            p['id'] || p[:id] || p['sku'] || p[:sku] || p['itemNoGlobal'] || p[:itemNoGlobal] || p['itemNo'] || p[:itemNo]
          }.compact
          
          bestseller_skus.concat(skus)
          Rails.logger.info "BestsellersFetcher: Found #{skus.length} products from category #{category.name} (ID: #{category.ikea_id}, total: #{bestseller_skus.length})"
        end
      rescue => e
        Rails.logger.warn "BestsellersFetcher: Failed to fetch products from category #{category.ikea_id}: #{e.message}"
        next
      end
    end
    
    Rails.logger.info "BestsellersFetcher: Total collected #{bestseller_skus.length} unique SKUs from #{top_categories.length} categories"
    bestseller_skus.uniq.first(limit)
  end
  
  def fetch_via_html(limit: 100)
    Rails.logger.info "BestsellersFetcher: Fetching bestsellers from HTML page"
    
    begin
      html = fetch_with_proxy(BESTSELLERS_URL)
    rescue => e
      Rails.logger.warn "BestsellersFetcher: Failed to fetch from #{BESTSELLERS_URL}: #{e.message}"
      # Пробуем альтернативные URL
      alternative_urls = [
        'https://www.ikea.com/pl/pl/cat/bestsellers/',
        'https://www.ikea.com/pl/pl/cat/hity/',
        'https://www.ikea.com/pl/pl/cat/popularne-produkty/'
      ]
      
      html = nil
      alternative_urls.each do |alt_url|
        begin
          Rails.logger.info "BestsellersFetcher: Trying alternative URL: #{alt_url}"
          html = fetch_with_proxy(alt_url)
          break if html
        rescue => alt_e
          Rails.logger.warn "BestsellersFetcher: Alternative URL #{alt_url} also failed: #{alt_e.message}"
        end
      end
      
      return [] unless html
    end
    
    return [] unless html
    
    doc = Nokogiri::HTML(html)
    bestseller_skus = []
    
    # Ищем SKU продуктов в различных селекторах
    doc.css('[data-product-id], [data-sku], [data-item-no], .product-item, .pip-product-compact').each do |product_elem|
      sku = product_elem['data-product-id'] || 
            product_elem['data-sku'] || 
            product_elem['data-item-no'] ||
            product_elem['data-item-no-global']
      
      if sku.present?
        bestseller_skus << sku.to_s
        break if bestseller_skus.length >= limit
      end
    end
    
    # Ищем в ссылках на продукты
    doc.css('a[href*="/p/"]').each do |link|
      href = link['href']
      next unless href
      
      # Формат: /pl/pl/p/{sku}/
      if match = href.match(%r{/p/([^/]+)/?})
        sku = match[1]
        bestseller_skus << sku unless bestseller_skus.include?(sku)
        break if bestseller_skus.length >= limit
      end
    end
    
    # Ищем в JSON-LD или data-атрибутах
    doc.css('script[type="application/ld+json"]').each do |script|
      begin
        data = JSON.parse(script.text)
        extract_skus_from_json(data, bestseller_skus, limit)
      rescue JSON::ParserError
        next
      end
    end
    
    # Ищем в data-hydration-props
    doc.css('script').each do |script|
      script_text = script.text
      if script_text.include?('__INITIAL_STATE__') || script_text.include?('data-hydration-props')
        extract_skus_from_script(script_text, bestseller_skus, limit)
      end
    end
    
    bestseller_skus.uniq.first(limit)
  end
  
  def fetch_with_proxy(url, max_redirects: 5)
    ProxyRotator.with_proxy_retry do |proxy_options|
      current_url = url
      redirects_count = 0
      
      loop do
        uri = URI.parse(current_url)
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = 30
        
        if proxy_options && proxy_options[:http_proxyaddr]
          http.proxy_from_env = false
          http.proxy_address = proxy_options[:http_proxyaddr]
          http.proxy_port = proxy_options[:http_proxyport]
          http.proxy_user = proxy_options[:http_proxyuser]
          http.proxy_pass = proxy_options[:http_proxypass]
        end
        
        request = Net::HTTP::Get.new(uri.path + (uri.query ? "?#{uri.query}" : ''))
        request['User-Agent'] = ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
        request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        request['Accept-Language'] = 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7'
        
        response = http.request(request)
        
        # Обработка редиректов
        if response.is_a?(Net::HTTPRedirection)
          redirects_count += 1
          if redirects_count > max_redirects
            raise StandardError, "Too many redirects (max: #{max_redirects})"
          end
          
          location = response['location']
          if location
            # Если location относительный, делаем его абсолютным
            current_url = location.start_with?('http') ? location : URI.join(current_url, location).to_s
            Rails.logger.info "BestsellersFetcher: Following redirect #{redirects_count} to #{current_url}"
            next
          else
            raise StandardError, "HTTP redirect (#{response.code}) without Location header"
          end
        elsif response.is_a?(Net::HTTPSuccess)
          return response.body
        else
          raise StandardError, "HTTP error: #{response.code} #{response.message}"
        end
      end
    end
  end
  
  def extract_skus_from_json(data, skus, limit)
    return if skus.length >= limit
    
    case data
    when Hash
      # Ищем SKU в различных полях
      ['id', 'sku', 'productId', 'itemNo', 'itemNoGlobal'].each do |key|
        if data[key].present?
          skus << data[key].to_s unless skus.include?(data[key].to_s)
          return if skus.length >= limit
        end
      end
      
      # Рекурсивно ищем в значениях
      data.each_value { |v| extract_skus_from_json(v, skus, limit) }
    when Array
      data.each { |item| extract_skus_from_json(item, skus, limit) }
    end
  end
  
  def extract_skus_from_script(script_text, skus, limit)
    return if skus.length >= limit
    
    # Ищем SKU в различных форматах
    # Формат: 403.411.01 или 40341101
    script_text.scan(/(\d{3}\.?\d{3}\.?\d{2})/) do |match|
      sku = match[0].gsub('.', '')
      skus << sku unless skus.include?(sku)
      return if skus.length >= limit
    end
    
    # Ищем в структурах типа "id": "403.411.01"
    script_text.scan(/["']id["']\s*:\s*["']([^"']+)["']/i) do |match|
      skus << match[0] unless skus.include?(match[0])
      return if skus.length >= limit
    end
  end
end

