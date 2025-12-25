# Парсер популярных категорий IKEA
# Основан на логике из оригинального JS-парсера
# Использует данные из API категорий (флаг isPopular) и категории с большим количеством продуктов
require 'nokogiri'
require 'net/http'
require 'uri'
require 'json'

class PopularCategoriesFetcher
  def self.fetch
    new.fetch
  end
  
  def fetch
    Rails.logger.info "PopularCategoriesFetcher: Fetching popular categories from API"
    
    popular_category_ids = []
    
    # Подход 1: Получаем категории с флагом isPopular из API
    begin
      categories_data = IkeaApiService.fetch_categories
      if categories_data
        popular_ids_from_api = extract_popular_from_api(categories_data)
        popular_category_ids.concat(popular_ids_from_api)
        Rails.logger.info "PopularCategoriesFetcher: Found #{popular_ids_from_api.length} popular categories from API (isPopular flag)"
      end
    rescue => e
      Rails.logger.warn "PopularCategoriesFetcher: Failed to fetch from API: #{e.message}"
    end
    
    # Подход 2: Категории с большим количеством продуктов (топ категории)
    begin
      top_category_ids = Category.active
                                 .joins(:products)
                                 .group('categories.ikea_id')
                                 .having('COUNT(products.id) > ?', 20)
                                 .order('COUNT(products.id) DESC')
                                 .limit(50)
                                 .pluck('categories.ikea_id')
      
      popular_category_ids.concat(top_category_ids)
      Rails.logger.info "PopularCategoriesFetcher: Found #{top_category_ids.length} top categories (by product count)"
    rescue => e
      Rails.logger.warn "PopularCategoriesFetcher: Failed to get top categories: #{e.message}"
    end
    
    # Убираем дубликаты
    popular_category_ids.uniq!
    
    Rails.logger.info "PopularCategoriesFetcher: Total found #{popular_category_ids.length} popular category IDs"
    if popular_category_ids.any?
      Rails.logger.info "PopularCategoriesFetcher: First 20 IDs: #{popular_category_ids.first(20).inspect}"
    end
    popular_category_ids
  end
  
  private
  
  def extract_popular_from_api(nodes, popular_ids = [])
    Array(nodes).each do |node|
      ikea_id = node['id'] || node['categoryId']
      next unless ikea_id
      
      # Проверяем флаг isPopular
      is_popular = node['isPopular'] || 
                   node['is_popular'] || 
                   node['popular'] || 
                   false
      
      if is_popular
        popular_ids << ikea_id unless popular_ids.include?(ikea_id)
      end
      
      # Рекурсивно обрабатываем дочерние категории
      children = node['subs'] || node['children']
      if children && children.any?
        extract_popular_from_api(children, popular_ids)
      end
    end
    
    popular_ids
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
            Rails.logger.info "PopularCategoriesFetcher: Following redirect #{redirects_count} to #{current_url}"
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
  
  def extract_category_ids_from_json(data, category_ids)
    case data
    when Hash
      # Ищем categoryId, id, category_id
      if data['categoryId'] || data['category_id'] || data['id']
        id = data['categoryId'] || data['category_id'] || data['id']
        category_ids << id.to_s if id.present?
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
      category_ids << match[0] if match[0].present?
    end
    
    # Ищем UUID категорий
    script_text.scan(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i) do |match|
      category_ids << match[0] if match[0].present?
    end
  end
end

