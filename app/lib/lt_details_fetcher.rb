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
    
    # Материалы - извлекаем HTML и текст
    materials_elem = product_doc.css('#materials-details').first
    if materials_elem
      material_html = materials_elem.inner_html
      material_text = materials_elem.text.strip
      result[:material_text] = material_html if material_html.present?
      result[:materials] = material_text if material_text.present?
      Rails.logger.debug "LtDetailsFetcher: Found materials: #{material_text.length} chars"
    end
    
    # "Полезно знать" (good-details) - извлекаем HTML и текст
    good_elem = product_doc.css('#good-details').first
    if good_elem
      good_html = good_elem.inner_html
      good_text = good_elem.text.strip
      result[:good_text] = good_html if good_html.present?
      result[:good_to_know] = good_text if good_text.present?
      Rails.logger.debug "LtDetailsFetcher: Found good-to-know: #{good_text.length} chars"
    end
    
    # Описание (product-details-content) - извлекаем HTML и текст
    details_elem = product_doc.css('.product-details-content').first
    if details_elem
      details_html = details_elem.inner_html
      details_text = details_elem.text.strip
      result[:details_text] = details_html if details_html.present?
      result[:content] = details_text if details_text.present?
      Rails.logger.debug "LtDetailsFetcher: Found details: #{details_text.length} chars"
    end
    
    # Дополнительно ищем материалы в других местах (на случай изменения структуры)
    if result[:materials].blank?
      # Пробуем альтернативные селекторы
      alt_materials = product_doc.css('[id*="material"], [class*="material"]').first
      if alt_materials
        result[:materials] = alt_materials.text.strip
        result[:material_text] = alt_materials.inner_html
        Rails.logger.debug "LtDetailsFetcher: Found materials via alternative selector"
      end
    end
    
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

