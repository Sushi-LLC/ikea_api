# Парсер детальной страницы продукта IKEA Lithuania (для переводов)
require 'nokogiri'
require 'net/http'
require 'uri'

class LtDetailsFetcher
  SEARCH_URL = 'https://www.ikea.lt/ru/search/?q='
  
  def self.fetch(item_no)
    new.fetch(item_no)
  end
  
  def fetch(item_no)
    # Поиск товара
    search_url = "#{SEARCH_URL}#{item_no}"
    search_html = fetch_with_proxy(search_url)
    search_doc = Nokogiri::HTML(search_html)
    
    # Находим ссылку на товар
    product_link = search_doc.css('.js-variant-result .card-body .itemInfo a').first
    return { translated: false } unless product_link
    
    href = product_link['href']
    href = "https://www.ikea.lt#{href}" unless href.start_with?('http')
    
    # Загружаем страницу товара
    product_html = fetch_with_proxy(href)
    product_doc = Nokogiri::HTML(product_html)
    
    result = { translated: true }
    
    # Название товара
    name = product_doc.css('h1 .itemFacts').text.strip
    result[:name] = clean_product_name(name) if name.present?
    
    # Материалы
    material_text = product_doc.css('#materials-details').inner_html
    result[:material_text] = material_text if material_text.present?
    
    # Детали товара
    good_text = product_doc.css('#good-details').inner_html
    result[:good_text] = good_text if good_text.present?
    
    # Описание
    details_text = product_doc.css('.product-details-content').inner_html
    result[:details_text] = details_text if details_text.present?
    
    result
  end
  
  private
  
  def clean_product_name(name)
    # Удаляем дополнительную информацию после запятой
    markers = [
      /\s*,\s*\d+\s*(предм|шт|штук|item|items|szt|sztuk|szt\.)/i,
      /\s*,\s*\d+\s*(x|×)\s*\d+/i,
      /\s*,\s*(цвет|в цвете|цвета):/i
    ]
    
    first_comma = name.index(',')
    if first_comma
      after_comma = name[first_comma..-1]
      markers.each do |marker|
        if marker.match?(after_comma)
          return name[0...first_comma].strip
        end
      end
    end
    
    name.strip
  end
  
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
      
      request = Net::HTTP::Get.new(uri.path)
      request['User-Agent'] = ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
      
      response = http.request(request)
      
      if response.is_a?(Net::HTTPSuccess)
        response.body
      else
        raise StandardError, "HTTP error: #{response.code} #{response.message}"
      end
    end
  end
end

