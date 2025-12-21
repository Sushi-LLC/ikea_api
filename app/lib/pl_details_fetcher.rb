# Парсер детальной страницы продукта IKEA Poland
require 'nokogiri'
require 'net/http'
require 'uri'

class PlDetailsFetcher
  def self.fetch(url)
    new.fetch(url)
  end
  
  def fetch(url)
    full_url = url.start_with?('http') ? url : "https://www.ikea.com#{url}"
    
    html = fetch_with_proxy(full_url)
    doc = Nokogiri::HTML(html)
    
    result = {}
    
    # JSON-LD Product schema
    product_schema = extract_json_ld(doc)
    if product_schema
      result[:name] = product_schema['name']
      result[:sku] = product_schema['mpn']
      result[:images] = Array(product_schema['image'])
      if product_schema['offers']
        result[:price] = product_schema['offers']['price']
      end
    end
    
    # Collection
    collection = doc.css('.pip-header-section__title--big').text.strip
    result[:collection] = collection if collection.present?
    
    # Product data (hydration props)
    product_data_attr = doc.css('.js-product-pip').first&.attribute('data-hydration-props')&.value
    product_data = nil
    
    if product_data_attr
      begin
        product_data = JSON.parse(product_data_attr)
        result[:product_data] = product_data
        
        # Set items
        result[:set_items] = extract_set_items(product_data, doc)
        
        # Bundle items
        result[:bundle_items] = extract_bundle_items(product_data, doc)
        
        # Related products
        result[:related_products] = extract_related_products(product_data)
      rescue JSON::ParserError => e
        Rails.logger.warn("Failed to parse product data: #{e.message}")
      end
    end
    
    # Weight, dimensions, etc.
    result.merge!(extract_packaging_info(doc, product_data))
    
    # Videos
    result[:videos] = extract_videos(doc, product_data)
    
    # Manuals
    result[:manuals] = extract_manuals(doc, product_data)
    
    result
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
  
  def extract_json_ld(doc)
    doc.css('script[type="application/ld+json"]').each do |script|
      begin
        data = JSON.parse(script.text)
        return data if data['@type'] == 'Product'
      rescue JSON::ParserError
        next
      end
    end
    nil
  end
  
  def extract_set_items(product_data, doc)
    possible_paths = [
      product_data&.dig('productSetSection', 'items'),
      product_data&.dig('setSection', 'items'),
      product_data&.dig('setItems'),
      product_data&.dig('productSet', 'items')
    ]
    
    items = []
    possible_paths.each do |path|
      if path.is_a?(Array) && path.any?
        items = path.map { |item| item['itemNo'] || item['itemNoGlobal'] || item }
                    .compact
                    .select { |item_no| item_no.to_s.match?(/^[0-9a-zA-Z]+$/) }
        break if items.any?
      end
    end
    
    # Если не нашли в JSON, пробуем HTML
    if items.empty?
      doc.css('.pip-product-set-section, .pip-set-items').each do |section|
        section.css('[data-item-no], .pip-item-no').each do |el|
          item_no = el['data-item-no'] || el.text.strip
          items << item_no if item_no.match?(/^[0-9a-zA-Z]+$/)
        end
      end
    end
    
    items.uniq
  end
  
  def extract_bundle_items(product_data, doc)
    possible_paths = [
      product_data&.dig('bundleSection', 'items'),
      product_data&.dig('bundleItems'),
      product_data&.dig('productBundle', 'items')
    ]
    
    items = []
    possible_paths.each do |path|
      if path.is_a?(Array) && path.any?
        items = path.map { |item| item['itemNo'] || item['itemNoGlobal'] || item }
                    .compact
                    .select { |item_no| item_no.to_s.match?(/^[0-9a-zA-Z]+$/) }
        break if items.any?
      end
    end
    
    items.uniq
  end
  
  def extract_related_products(product_data)
    product_data&.dig('addOns', 'addOns')&.flat_map do |addon|
      addon['items']&.select { |item| item['itemType'] == 'ART' }
                  &.map { |item| item['itemNo'] }
                  &.compact || []
    end || []
  end
  
  def extract_packaging_info(doc, product_data)
    result = {}
    
    # Извлекаем информацию об упаковке из productData или HTML
    packaging = product_data&.dig('stockcheckSection', 'packagingProps', 'packages')
    
    if packaging.is_a?(Array) && packaging.any?
      total_weight = packaging.sum { |pkg| (pkg['weight'] || 0).to_f }
      result[:weight] = total_weight if total_weight > 0
      
      # Первая упаковка для netWeight
      first_pkg = packaging.first
      if first_pkg
        result[:net_weight] = (first_pkg['netWeight'] || 0).to_f if first_pkg['netWeight']
        result[:package_volume] = (first_pkg['volume'] || 0).to_f if first_pkg['volume']
        
        if first_pkg['measurements']
          dims = first_pkg['measurements']
          result[:package_dimensions] = "#{dims['width']} × #{dims['height']} × #{dims['length']}"
        end
        
        # Dimensions из первой упаковки
        if first_pkg['dimensions']
          dims = first_pkg['dimensions']
          result[:dimensions] = "#{dims['width']} × #{dims['height']} × #{dims['length']}"
        end
      end
    end
    
    result
  end
  
  def extract_videos(doc, product_data)
    videos = []
    
    # Из productData
    video_section = product_data&.dig('videoSection') || product_data&.dig('mediaSection')
    if video_section
      if video_section.is_a?(Array)
        videos.concat(video_section.map { |v| v['url'] || v['src'] }.compact)
      elsif video_section.is_a?(Hash)
        videos << video_section['url'] if video_section['url']
      end
    end
    
    # Из HTML
    doc.css('iframe[src*="youtube"], iframe[src*="vimeo"], video source').each do |el|
      src = el['src'] || el['data-src']
      videos << src if src.present?
    end
    
    videos.uniq.compact
  end
  
  def extract_manuals(doc, product_data)
    manuals = []
    
    # Из productData
    attachments = product_data&.dig('productInformationSection', 'attachments', 'manual')
    if attachments
      if attachments.is_a?(Array)
        manuals.concat(attachments.map { |m| m['url'] || m }.compact)
      else
        manuals << attachments['url'] if attachments['url']
      end
    end
    
    # Из HTML
    doc.css('a[href*="manual"], a[href*="instruction"]').each do |link|
      href = link['href']
      manuals << href if href.present?
    end
    
    manuals.uniq.compact
  end
end

