# Сервис для расширенного поиска продуктов по категориям с цифровым кодом
# Предоставляет несколько стратегий поиска для максимального покрытия
class CategoryProductsSearchService
  STRATEGIES = [
    :api_by_category_id,      # 1. Стандартный API поиск по ID категории
    :api_by_category_name,     # 2. API поиск по названию категории
    :html_parsing,             # 3. HTML парсинг страницы категории
    :html_with_js_rendering,   # 4. HTML парсинг с ожиданием JS (если нужно)
    :api_alternative_endpoint  # 5. Альтернативный API endpoint (если есть)
  ].freeze

  def self.search(category, offset: 0, limit: 50, strategies: STRATEGIES)
    new.search(category, offset: offset, limit: limit, strategies: strategies)
  end

  def search(category, offset: 0, limit: 50, strategies: STRATEGIES)
    results = []
    tried_strategies = []

    strategies.each do |strategy|
      next if tried_strategies.include?(strategy)

      Rails.logger.info "CategoryProductsSearchService: Trying strategy #{strategy} for category #{category.ikea_id} (#{category.name})"

      begin
        case strategy
        when :api_by_category_id
          results = try_api_by_category_id(category, offset, limit)
        when :api_by_category_name
          results = try_api_by_category_name(category, offset, limit)
        when :html_parsing
          results = try_html_parsing(category, offset, limit)
        when :html_with_js_rendering
          results = try_html_with_js_rendering(category, offset, limit)
        when :api_alternative_endpoint
          results = try_api_alternative_endpoint(category, offset, limit)
        end

        if results.any?
          Rails.logger.info "CategoryProductsSearchService: Strategy #{strategy} found #{results.length} products for category #{category.ikea_id}"
          return results
        end

        tried_strategies << strategy
      rescue => e
        Rails.logger.warn "CategoryProductsSearchService: Strategy #{strategy} failed for category #{category.ikea_id}: #{e.message}"
        tried_strategies << strategy
        next
      end
    end

    Rails.logger.warn "CategoryProductsSearchService: All strategies exhausted for category #{category.ikea_id} (#{category.name})"
    []
  end

  private

  # Стратегия 1: Стандартный API поиск по ID категории
  def try_api_by_category_id(category, offset, limit)
    return [] if category.ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    
    IkeaApiService.search_products_by_category(
      category.ikea_id,
      offset: offset,
      limit: limit
    )
  end

  # Стратегия 2: API поиск по названию категории (если ID не работает)
  def try_api_by_category_name(category, offset, limit)
    return [] unless category.name.present?
    
    # Пробуем поиск по названию через API
    # Используем тот же endpoint, но с типом поиска по тексту
    search_term = category.name.split(' ').first(3).join(' ') # Берем первые 3 слова
    
    ProxyRotator.with_proxy_retry do |proxy_options|
      response = HTTParty.post(
        'https://sik.search.blue.cdtapps.com/pl/pl/search?c=listaf&v=20241114',
        body: {
          searchParameters: {
            input: search_term,
            type: 'TEXT' # Поиск по тексту вместо категории
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

      parse_api_response(response)
    end
  rescue => e
    Rails.logger.warn "CategoryProductsSearchService.try_api_by_category_name failed: #{e.message}"
    []
  end

  # Стратегия 3: HTML парсинг страницы категории
  def try_html_parsing(category, offset, limit)
    return [] unless category.url.present?
    
    CategoryProductsFetcher.fetch(
      category.url,
      offset: offset,
      limit: limit
    )
  rescue => e
    Rails.logger.warn "CategoryProductsSearchService.try_html_parsing failed: #{e.message}"
    []
  end

  # Стратегия 4: HTML парсинг с ожиданием JS рендеринга (если нужно)
  def try_html_with_js_rendering(category, offset, limit)
    return [] unless category.url.present?
    
    # Если есть Ferrum или другой headless browser, можно использовать его
    # Пока используем обычный HTML парсинг, но с дополнительными попытками
    # Можно добавить задержку для ожидания JS рендеринга
    sleep(1) # Небольшая задержка для возможного JS рендеринга
    
    try_html_parsing(category, offset, limit)
  rescue => e
    Rails.logger.warn "CategoryProductsSearchService.try_html_with_js_rendering failed: #{e.message}"
    []
  end

  # Стратегия 5: Альтернативный API endpoint (если есть)
  def try_api_alternative_endpoint(category, offset, limit)
    return [] if category.ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    
    # Пробуем альтернативный endpoint для поиска продуктов
    # Например, через категорийный API с другими параметрами
    ProxyRotator.with_proxy_retry do |proxy_options|
      # Пробуем поиск через другой формат запроса
      response = HTTParty.post(
        'https://sik.search.blue.cdtapps.com/pl/pl/search?c=listaf&v=20241114',
        body: {
          searchParameters: {
            input: category.ikea_id.to_s,
            type: 'CATEGORY',
            filters: [] # Пустые фильтры для максимального покрытия
          },
          zip: ENV.fetch('IKEA_ZIP', '01-106'),
          store: ENV.fetch('IKEA_STORE', '307'),
          isUserLoggedIn: false,
          components: [{
            component: 'PRIMARY_AREA',
            columns: 4,
            types: {
              main: 'PRODUCT'
            },
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

      parse_api_response(response)
    end
  rescue => e
    Rails.logger.warn "CategoryProductsSearchService.try_api_alternative_endpoint failed: #{e.message}"
    []
  end

  def parse_api_response(response)
    return [] unless response.success?

    items = response.dig('results', 0, 'items') || []
    products = items.select { |item| item['type'] == 'PRODUCT' }
                   .map { |item| item['product'] }
    
    products
  end
end

