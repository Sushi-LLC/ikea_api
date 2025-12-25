# Парсер детальной страницы продукта IKEA Poland
require 'nokogiri'
require 'net/http'
require 'uri'
require 'ferrum'

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
      
      # Извлекаем размеры из JSON-LD
      if product_schema['width'] || product_schema['height'] || product_schema['depth']
        width = product_schema['width']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
        height = product_schema['height']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
        depth = product_schema['depth']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
        
        if width && depth
          result[:dimensions] = "#{width} × #{depth} × #{height || 'N/A'} cm"
          Rails.logger.debug "PlDetailsFetcher: Dimensions from JSON-LD: #{result[:dimensions]}"
        end
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
        result[:related_products] = extract_related_products(product_data, doc)
      rescue JSON::ParserError => e
        Rails.logger.warn("Failed to parse product data: #{e.message}")
      end
    end
    
    # Weight, dimensions, etc. (обязательно вызываем, даже если product_data пустой)
    packaging_info = extract_packaging_info(doc, product_data)
    result.merge!(packaging_info)
    Rails.logger.info "PlDetailsFetcher: Packaging info extracted - weight: #{packaging_info[:weight]}, dimensions: #{packaging_info[:dimensions]}"
    
    # Product description and extended attributes (обязательно вызываем)
    description_data = extract_product_description(doc, product_data)
    result.merge!(description_data)
    Rails.logger.info "PlDetailsFetcher: Description data extracted - description: #{description_data[:description].present?}, materials: #{description_data[:materials].present?}"
    
    # Images - извлекаем все изображения со страницы продукта
    all_images = extract_images(doc, product_data, result[:images] || [])
    result[:images] = all_images if all_images.any?
    
    # Videos
    result[:videos] = extract_videos(doc, product_data)
    
    # Manuals
    result[:manuals] = extract_manuals(doc, product_data)
    
    # Извлекаем наличие из HTML (если доступно)
    result[:availability] = extract_availability(doc, product_data)
    
    # Извлекаем данные из модального окна с описанием продукта
    modal_data = extract_modal_details(doc)
    
    # Если модальное окно не найдено или данные неполные, используем headless браузер
    if modal_data[:materials].blank? || modal_data[:care_instructions].blank? || modal_data[:safety_info].blank?
      Rails.logger.info "PlDetailsFetcher: Modal data incomplete, trying headless browser"
      headless_modal_data = fetch_modal_with_headless_browser(full_url)
      modal_data.merge!(headless_modal_data) if headless_modal_data.present?
    end
    
    result.merge!(modal_data)
    
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
  
  # Загрузка модального окна через headless браузер
  def fetch_modal_with_headless_browser(url)
    result = {}
    browser = nil
    
    begin
      Rails.logger.info "PlDetailsFetcher.fetch_modal_with_headless_browser: Starting headless browser for #{url}"
      
      # Получаем прокси для headless браузера
      proxy_options = ProxyRotator.get_proxy
      proxy_string = nil
      
      if proxy_options && proxy_options[:http_proxyaddr]
        proxy_string = "#{proxy_options[:http_proxyaddr]}:#{proxy_options[:http_proxyport]}"
        if proxy_options[:http_proxyuser] && proxy_options[:http_proxypass]
          proxy_string = "#{proxy_options[:http_proxyuser]}:#{proxy_options[:http_proxypass]}@#{proxy_string}"
        end
        Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Using proxy: #{proxy_options[:http_proxyaddr]}:#{proxy_options[:http_proxyport]}"
      end
      
      browser_options = {
        'no-sandbox' => nil,
        'disable-dev-shm-usage' => nil,
        'disable-gpu' => nil,
        'disable-software-rasterizer' => nil,
        'disable-extensions' => nil,
        'disable-background-networking' => nil,
        'disable-background-timer-throttling' => nil,
        'disable-backgrounding-occluded-windows' => nil,
        'disable-breakpad' => nil,
        'disable-client-side-phishing-detection' => nil,
        'disable-default-apps' => nil,
        'disable-hang-monitor' => nil,
        'disable-popup-blocking' => nil,
        'disable-prompt-on-repost' => nil,
        'disable-sync' => nil,
        'disable-translate' => nil,
        'metrics-recording-only' => nil,
        'no-first-run' => nil,
        'safebrowsing-disable-auto-update' => nil,
        'password-store=basic' => nil,
        'use-mock-keychain' => nil
      }
      
      browser_options['proxy-server'] = proxy_string if proxy_string
      
      browser = Ferrum::Browser.new(
        headless: true,
        browser_options: browser_options,
        timeout: 60
      )
      
      # Устанавливаем User-Agent для обхода защиты
      browser.headers.set({
        'User-Agent' => ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'),
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language' => 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding' => 'gzip, deflate, br',
        'Connection' => 'keep-alive',
        'Upgrade-Insecure-Requests' => '1',
        'Sec-Fetch-Dest' => 'document',
        'Sec-Fetch-Mode' => 'navigate',
        'Sec-Fetch-Site' => 'none',
        'Cache-Control' => 'max-age=0'
      })
      
      # Загружаем страницу
      browser.go_to(url)
      
      # Ждем загрузки страницы и прохождения Cloudflare проверки
      browser.network.wait_for_idle(timeout: 20)
      sleep(5) # Дополнительная пауза для прохождения Cloudflare и загрузки динамического контента
      
      # Проверяем, не попали ли мы на страницу Cloudflare
      page_html = browser.body
      if page_html.length < 10000 || page_html.include?('Cloudflare') || page_html.include?('Just a moment')
        Rails.logger.warn "PlDetailsFetcher.fetch_modal_with_headless_browser: Possible Cloudflare protection, waiting longer..."
        sleep(10) # Ждем прохождения Cloudflare проверки
        page_html = browser.body
      end
      
      Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Page loaded, HTML length: #{page_html.length}"
      
      # Ищем кнопку для открытия модального окна "Информация о продукте"
      modal_opened = false
      
      # Пробуем открыть через JavaScript (более надежно)
      begin
        button_info = browser.evaluate(<<~JS)
          (function() {
            // Ищем кнопку "Информация о продукте"
            const buttons = Array.from(document.querySelectorAll('button, a'));
            const infoButton = buttons.find(btn => {
              const text = btn.textContent || '';
              const id = btn.closest('[id*="pipf-product-information-section-list-0"]');
              const ariaControls = btn.getAttribute('aria-controls');
              return text.includes('Информация о продукте') || 
                     text.includes('Informacja o produkcie') ||
                     (ariaControls && ariaControls.includes('product-details')) ||
                     id !== null;
            });
            if (infoButton) {
              return {
                found: true,
                text: infoButton.textContent,
                id: infoButton.id,
                className: infoButton.className
              };
            }
            return { found: false, buttonsCount: buttons.length };
          })();
        JS
        
        if button_info && button_info['found']
          Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Found button via JS: #{button_info['text']}"
          clicked = browser.evaluate(<<~JS)
            (function() {
              const buttons = Array.from(document.querySelectorAll('button, a'));
              const infoButton = buttons.find(btn => {
                const text = btn.textContent || '';
                const id = btn.closest('[id*="pipf-product-information-section-list-0"]');
                const ariaControls = btn.getAttribute('aria-controls');
                return text.includes('Информация о продукте') || 
                       text.includes('Informacja o produkcie') ||
                       (ariaControls && ariaControls.includes('product-details')) ||
                       id !== null;
              });
              if (infoButton) {
                infoButton.click();
                return true;
              }
              return false;
            })();
          JS
          modal_opened = clicked if clicked
          Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Button clicked: #{modal_opened}"
        else
          Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Button not found via JS. Buttons count: #{button_info ? button_info['buttonsCount'] : 'unknown'}"
        end
        sleep(2) if modal_opened
      rescue => e
        Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Error opening modal via JS: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      end
      
      # Если не открылось через JS, пробуем через CSS селекторы
      unless modal_opened
        modal_button_selectors = [
          '[id*="pipf-product-information-section-list-0"] button',
          'button[aria-controls*="product-details"]',
          '.pipf-list-view-item__action',
          '#pipf-product-information-section-list-0 button'
        ]
        
        modal_button_selectors.each do |selector|
          begin
            button = browser.at_css(selector)
            if button
              Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Found button with selector: #{selector}"
              button.click
              sleep(2)
              modal_opened = true
              break
            end
          rescue => e
            Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Error clicking button: #{e.message}"
            next
          end
        end
      end
      
      # Ждем появления модального окна (проверяем явно)
      if modal_opened
        Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Waiting for modal to appear..."
        # Ждем до 5 секунд появления модального окна
        10.times do |i|
          sleep(0.5)
          modal_exists = browser.evaluate(<<~JS)
            (function() {
              return document.querySelector('.pipf-product-details-modal, [aria-modal="true"], [id*="product-details"]') !== null;
            })();
          JS
          if modal_exists
            Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Modal appeared after #{i * 0.5} seconds"
            break
          end
        end
        sleep(1) # Дополнительная пауза для полной загрузки контента модального окна
      else
        Rails.logger.warn "PlDetailsFetcher.fetch_modal_with_headless_browser: Modal button was not clicked, trying to extract from page anyway"
      end
      
      # Получаем HTML страницы после открытия модального окна
      page_html = browser.body
      Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Final HTML length: #{page_html.length}"
      modal_doc = Nokogiri::HTML(page_html)
      
      # Проверяем наличие модального окна в HTML
      modal_found = modal_doc.css('.pipf-product-details-modal, [aria-modal="true"], [id*="product-details"]').any?
      Rails.logger.debug "PlDetailsFetcher.fetch_modal_with_headless_browser: Modal found in HTML: #{modal_found}"
      
      # Извлекаем данные из модального окна
      result = extract_modal_details(modal_doc)
      
      Rails.logger.info "PlDetailsFetcher.fetch_modal_with_headless_browser: Extracted - materials: #{result[:materials].present?}, care: #{result[:care_instructions].present?}, safety: #{result[:safety_info].present?}, good_to_know: #{result[:good_to_know].present?}"
      
      browser.quit
      result
      
    rescue => e
      Rails.logger.error "PlDetailsFetcher.fetch_modal_with_headless_browser: Error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      browser&.quit rescue nil
      {}
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
  
  def extract_related_products(product_data, doc = nil)
    related = []
    
    Rails.logger.debug "PlDetailsFetcher.extract_related_products: Starting extraction"
    
    if product_data
      # Список всех возможных путей для связанных продуктов (как в JS-парсере)
      paths_to_check = [
        # Основные пути
        ['addOns', 'addOns'],
        ['addOns'],
        ['recommendedProducts'],
        ['recommended', 'products'],
        ['relatedProducts'],
        ['related', 'products'],
        ['productSuggestions'],
        ['suggestions'],
        ['productRecommendations'],
        ['recommendations'],
        ['suggestedProducts'],
        ['youMightAlsoLike'],
        ['complementaryProducts'],
        ['accessories'],
        ['accessoryProducts'],
        ['completeTheLook'],
        ['completeTheLookProducts'],
        ['frequentlyBoughtTogether'],
        ['boughtTogether'],
        ['similarProducts'],
        ['similar'],
        ['alternatives'],
        ['alternativeProducts'],
        # Вложенные пути
        ['productInformationSection', 'relatedProducts'],
        ['productInformationSection', 'recommendedProducts'],
        ['productInformationSection', 'accessories'],
        ['mediaSection', 'relatedProducts'],
        ['mediaSection', 'recommendedProducts'],
        ['productDetails', 'relatedProducts'],
        ['productDetails', 'recommendedProducts'],
        ['productDetails', 'accessories']
      ]
      
      paths_to_check.each do |path|
        items = product_data.dig(*path)
        next unless items.present?
        
        Rails.logger.debug "PlDetailsFetcher.extract_related_products: Checking path #{path.join('.')}: #{items.class}"
        
        # Обрабатываем массив
        if items.is_a?(Array)
          items.each do |item|
            item_no = extract_item_no_from_hash(item)
            if item_no.present?
              related << item_no.to_s
              Rails.logger.debug "PlDetailsFetcher.extract_related_products: Added from #{path.join('.')}: #{item_no}"
            end
          end
        # Обрабатываем объект с вложенными массивами
        elsif items.is_a?(Hash)
          # Ищем вложенные массивы items, products, etc.
          ['items', 'products', 'productsList', 'list'].each do |key|
            nested_items = items[key] || items[key.to_sym]
            if nested_items.is_a?(Array)
              nested_items.each do |item|
                item_no = extract_item_no_from_hash(item)
                if item_no.present?
                  related << item_no.to_s
                  Rails.logger.debug "PlDetailsFetcher.extract_related_products: Added from #{path.join('.')}.#{key}: #{item_no}"
                end
              end
            end
          end
          
          # Если сам объект содержит itemNo
          item_no = extract_item_no_from_hash(items)
          if item_no.present?
            related << item_no.to_s
            Rails.logger.debug "PlDetailsFetcher.extract_related_products: Added from #{path.join('.')} (direct): #{item_no}"
          end
        end
      end
      
      # Рекурсивный поиск в productData (на случай, если структура изменилась)
      find_related_in_hash(product_data, related)
    end
    
    # Извлечение из HTML (если есть doc)
    if doc
      # Расширенный список селекторов для связанных продуктов
      html_selectors = [
        '.pip-product-recommendations [data-item-no]',
        '.pip-related-products [data-item-no]',
        '.pip-recommendation [data-item-no]',
        '[data-product-id]',
        '[data-item-no]',
        '[data-sku]',
        '.pip-accessories [data-item-no]',
        '.pip-complete-the-look [data-item-no]',
        '.pip-frequently-bought-together [data-item-no]',
        '.product-recommendation [data-item-no]',
        'a[href*="/p/"]'
      ]
      
      html_related = doc.css(html_selectors.join(', '))
      Rails.logger.debug "PlDetailsFetcher.extract_related_products: Found #{html_related.length} HTML elements with related products"
      
      html_related.each do |el|
        # Из data-атрибутов
        item_no = el['data-item-no'] || el['data-product-id'] || el['data-sku'] || el['data-item-no-global']
        
        # Из href (формат: /pl/pl/p/{item_no}/)
        if item_no.blank? && el['href']
          match = el['href'].match(%r{/p/([^/]+)/?})
          item_no = match[1] if match
        end
        
        if item_no.present? && item_no.match?(/^[0-9a-zA-Z]+$/)
          related << item_no
          Rails.logger.debug "PlDetailsFetcher.extract_related_products: Added from HTML: #{item_no}"
        end
      end
    end
    
    result = related.compact.uniq
    Rails.logger.info "PlDetailsFetcher.extract_related_products: Extracted #{result.length} related products"
    result
  end
  
  # Вспомогательный метод для извлечения item_no из объекта
  def extract_item_no_from_hash(item)
    return nil unless item.is_a?(Hash)
    
    # Проверяем различные возможные поля
    item_no = item['itemNo'] || 
              item['itemNoGlobal'] || 
              item['item_no'] ||
              item['item_no_global'] ||
              item['id'] ||
              item['sku'] ||
              item['productId'] ||
              item['product_id'] ||
              item[:itemNo] ||
              item[:itemNoGlobal] ||
              item[:id] ||
              item[:sku]
    
    # Если item_no найден, проверяем тип (берем только товары, не категории)
    if item_no.present?
      item_type = item['itemType'] || item['type'] || item['item_type'] || item[:itemType] || item[:type]
      # Пропускаем категории и другие типы, если указан тип
      if item_type.present? && item_type != 'ART' && item_type != 'PRODUCT'
        return nil
      end
    end
    
    item_no
  end
  
  # Рекурсивный поиск связанных продуктов в хеше
  def find_related_in_hash(hash, related, depth = 0)
    return if depth > 5  # Ограничиваем глубину рекурсии
    
    case hash
    when Hash
      # Проверяем, не является ли это объектом продукта
      if hash['itemNo'] || hash['itemNoGlobal'] || hash['id'] || hash['sku']
        item_no = extract_item_no_from_hash(hash)
        if item_no.present? && !related.include?(item_no.to_s)
          related << item_no.to_s
          Rails.logger.debug "PlDetailsFetcher.find_related_in_hash: Found item_no: #{item_no}"
        end
      end
      
      # Рекурсивно обходим значения
      hash.each_value { |v| find_related_in_hash(v, related, depth + 1) }
    when Array
      hash.each { |item| find_related_in_hash(item, related, depth + 1) }
    end
  end
  
  def extract_packaging_info(doc, product_data)
    result = {}
    
    Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Starting extraction"
    
    # Расширенный список путей для информации об упаковке (как в JS-парсере)
    packaging_paths = [
      ['stockcheckSection', 'packagingProps', 'packages'],
      ['stockcheckSection', 'packaging', 'packages'],
      ['packaging', 'packages'],
      ['packagingProps', 'packages'],
      ['packages'],
      ['productInformationSection', 'packaging', 'packages'],
      ['productInformationSection', 'packagingProps', 'packages'],
      ['productDetails', 'packaging', 'packages'],
      ['productDetails', 'packagingProps', 'packages'],
      ['specifications', 'packaging', 'packages'],
      ['specifications', 'packagingProps', 'packages']
    ]
    
    packaging = nil
    packaging_paths.each do |path|
      packaging = product_data&.dig(*path)
      break if packaging.present?
    end
    
    Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: packaging found: #{packaging.present?}, type: #{packaging.class}"
    
    if packaging.is_a?(Array) && packaging.any?
      # Общий вес - сумма всех упаковок (в килограммах)
      total_weight = 0
      packaging.each do |pkg|
        weight = pkg['weight'] || pkg[:weight] || pkg['weightKg'] || pkg[:weightKg] || 0
        # Если вес в граммах, конвертируем в килограммы
        if weight.to_f > 0 && weight.to_f < 1
          weight = weight.to_f * 1000  # Предполагаем, что это уже в кг, но если < 1, возможно это в тоннах
        end
        total_weight += weight.to_f
      end
      result[:weight] = total_weight if total_weight > 0
      Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Total weight: #{result[:weight]}"
      
      # Обрабатываем все упаковки для получения полной информации
      packaging.each_with_index do |pkg, idx|
        # Чистый вес (netWeight) - берем из первой упаковки, если не указан
        if result[:net_weight].blank?
          net_weight = pkg['netWeight'] || pkg[:netWeight] || pkg['net_weight'] || pkg['netWeightKg'] || pkg[:netWeightKg]
          if net_weight
            result[:net_weight] = net_weight.to_f
            Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Net weight from package #{idx}: #{result[:net_weight]}"
          end
        end
        
        # Объём упаковки - берем из первой упаковки
        if result[:package_volume].blank?
          volume = pkg['volume'] || pkg[:volume] || pkg['volumeL'] || pkg[:volumeL] || pkg['volumeM3'] || pkg[:volumeM3]
          if volume
            # Если объём в м³, конвертируем в литры
            volume_value = volume.to_f
            volume_value *= 1000 if pkg['volumeM3'] || pkg[:volumeM3]  # м³ в литры
            result[:package_volume] = volume_value
            Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Package volume from package #{idx}: #{result[:package_volume]}"
          end
        end
        
        # Размеры упаковки (package_dimensions)
        if result[:package_dimensions].blank?
          measurements = pkg['measurements'] || pkg[:measurements] || pkg['packageMeasurements'] || pkg[:packageMeasurements]
          if measurements.is_a?(Hash)
            width = measurements['width'] || measurements[:width] || measurements['w']
            height = measurements['height'] || measurements[:height] || measurements['h']
            length = measurements['length'] || measurements[:length] || measurements['l'] || measurements['depth'] || measurements[:depth]
            if width && height && length
              result[:package_dimensions] = "#{width} × #{height} × #{length}"
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Package dimensions from package #{idx}: #{result[:package_dimensions]}"
            end
          end
        end
        
        # Размеры продукта (dimensions) - берем из первой упаковки
        if result[:dimensions].blank?
          dimensions = pkg['dimensions'] || pkg[:dimensions] || pkg['productDimensions'] || pkg[:productDimensions]
          if dimensions.is_a?(Hash)
            width = dimensions['width'] || dimensions[:width] || dimensions['w']
            height = dimensions['height'] || dimensions[:height] || dimensions['h']
            length = dimensions['length'] || dimensions[:length] || dimensions['l'] || dimensions['depth'] || dimensions[:depth]
            if width && height && length
              result[:dimensions] = "#{width} × #{height} × #{length}"
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Product dimensions from package #{idx}: #{result[:dimensions]}"
            end
          end
        end
        
        # Если нашли все необходимые данные, можно прервать цикл
        break if result[:net_weight].present? && result[:package_volume].present? && 
                result[:package_dimensions].present? && result[:dimensions].present?
      end
    end
    
    # Если не нашли в packaging, пробуем прямые пути в productData
    if result[:weight].blank?
      weight_paths = [
        ['weight'],
        ['weightKg'],
        ['productWeight'],
        ['totalWeight'],
        ['stockcheckSection', 'weight'],
        ['productInformationSection', 'weight']
      ]
      
      weight_paths.each do |path|
        weight = product_data&.dig(*path)
        if weight
          result[:weight] = weight.to_f
          Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Weight from #{path.join('.')}: #{result[:weight]}"
          break
        end
      end
    end
    
    # Если не нашли в productData, пробуем извлечь из HTML (улучшенный парсинг)
    if result[:weight].blank? || result[:dimensions].blank? || result[:package_dimensions].blank?
      Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Trying to extract from HTML"
      
      # Ищем в секции "Opakowanie" (Упаковка) - там обычно указаны размеры и вес упаковок
      # Собираем все секции с упаковкой
      packaging_sections = doc.css('.pip-product-details__section, .pip-specifications__section, [data-section], section, div, li, ul').select do |section|
        section_text = section.text.downcase
        (section_text.include?('opakowanie') || section_text.include?('paczk') || section_text.include?('paczka')) &&
        (section_text.include?('kg') || section_text.include?('waga') || section_text.include?('cm'))
      end
      
      if packaging_sections.any?
        Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Found #{packaging_sections.length} packaging sections"
        
        # Собираем все веса и берем самый большой (это обычно вес с упаковкой, например 37.55)
        if result[:weight].blank?
          weights_found = []
          packaging_sections.each do |section|
            section.text.scan(/([\d,\.]+)\s*kg/i) do |match|
              weight_value = match[0].gsub(',', '.').to_f
              # Собираем все веса в разумном диапазоне (5-100 кг)
              if weight_value >= 5 && weight_value <= 100
                weights_found << weight_value unless weights_found.include?(weight_value)
                Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Found package weight: #{weight_value} kg"
              end
            end
          end
          
          if weights_found.any?
            # Берем самый большой вес (это обычно вес с упаковкой, например 37.55)
            result[:weight] = weights_found.max.round(2)
            Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Using max weight from #{weights_found.length} found: #{result[:weight]} kg (all: #{weights_found.sort.inspect})"
          end
        end
        
        # Извлекаем размеры упаковки из первой найденной секции
        if result[:package_dimensions].blank?
          packaging_sections.each do |section|
            section_text = section.text
            width = section_text.match(/szerokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
            height = section_text.match(/wysokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
            length = section_text.match(/długość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
            
            if width && height && length
              result[:package_dimensions] = "#{width.gsub(',', '.')} × #{height.gsub(',', '.')} × #{length.gsub(',', '.')} cm"
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Package dimensions from packaging section: #{result[:package_dimensions]}"
              break
            end
          end
        end
      end
      
      # Ищем размеры продукта в секции "Wymiary" или в таблицах
      doc.css('.pip-product-details__section, .pip-specifications__section, [data-dimensions]').each do |section|
        section_text = section.text.downcase
        
        if section_text.include?('wymiary') || section_text.include?('rozmiar') || section_text.include?('wymiar')
          Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Found dimensions section"
          
          # Извлекаем размеры продукта
          if result[:dimensions].blank?
            # Пробуем найти в тексте (например, "Szerokość: 199 cm, Głębokość: 93 cm, Wysokość: 70 cm")
            width = section.text.match(/szerokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
            depth = section.text.match(/głębokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first || 
                   section.text.match(/głębokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
            height = section.text.match(/wysokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
            
            if width && depth && height
              result[:dimensions] = "#{width.gsub(',', '.')} × #{depth.gsub(',', '.')} × #{height.gsub(',', '.')} cm"
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Product dimensions from dimensions section: #{result[:dimensions]}"
            end
          end
        end
      end
      
      # Ищем в таблицах характеристик (более агрессивный поиск)
      doc.css('table, .pip-product-details-table, .pip-specifications-table, dl, .specification-list').each do |table|
        table.css('tr, dt, .specification-item').each do |row|
          label = (row.css('th, dt, .spec-label, [data-label]').first || row.css('td, dd').first)&.text&.strip&.downcase
          value = (row.css('td:last-child, dd, .spec-value, [data-value]').first || row.css('td').last)&.text&.strip
          
          next unless label && value
          
          # Вес (Waga)
          if result[:weight].blank? && (label.include?('waga') || label.include?('weight') || label.include?('masa'))
            weight_match = value.match(/([\d,\.]+)\s*(kg|кг|g|г)/i)
            if weight_match
              weight_value = weight_match[1].gsub(',', '.').to_f
              weight_value /= 1000 if value.match?(/g|г/i) && !value.match?(/kg|кг/i)
              result[:weight] = weight_value
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Weight from table: #{result[:weight]}"
            end
          end
          
          # Чистый вес (Waga netto)
          if result[:net_weight].blank? && (label.include?('waga netto') || label.include?('net weight') || label.include?('netto'))
            weight_match = value.match(/([\d,\.]+)\s*(kg|кг|g|г)/i)
            if weight_match
              weight_value = weight_match[1].gsub(',', '.').to_f
              weight_value /= 1000 if value.match?(/g|г/i) && !value.match?(/kg|кг/i)
              result[:net_weight] = weight_value
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Net weight from table: #{result[:net_weight]}"
            end
          end
          
          # Объём (Objętość)
          if result[:package_volume].blank? && (label.include?('objętość') || label.include?('volume') || label.include?('pojemność'))
            volume_match = value.match(/([\d,\.]+)\s*(l|л|м³|m³|litr)/i)
            if volume_match
              volume_value = volume_match[1].gsub(',', '.').to_f
              volume_value *= 1000 if value.match?(/м³|m³/i)  # м³ в литры
              result[:package_volume] = volume_value
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Volume from table: #{result[:package_volume]}"
            end
          end
          
          # Размеры продукта (Wymiary produktu)
          if result[:dimensions].blank? && (label.include?('wymiary produktu') || label.include?('wymiary') || label.include?('rozmiar'))
            # Пробуем извлечь из значения
            dims_match = value.match(/([\d,\.]+)\s*[×x]\s*([\d,\.]+)\s*[×x]\s*([\d,\.]+)/i)
            if dims_match
              result[:dimensions] = "#{dims_match[1].gsub(',', '.')} × #{dims_match[2].gsub(',', '.')} × #{dims_match[3].gsub(',', '.')}"
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Dimensions from table: #{result[:dimensions]}"
            end
          end
          
          # Размеры упаковки (Wymiary opakowania)
          if result[:package_dimensions].blank? && (label.include?('wymiary opakowania') || label.include?('rozmiar opakowania') || label.include?('package'))
            dims_match = value.match(/([\d,\.]+)\s*[×x]\s*([\d,\.]+)\s*[×x]\s*([\d,\.]+)/i)
            if dims_match
              result[:package_dimensions] = "#{dims_match[1].gsub(',', '.')} × #{dims_match[2].gsub(',', '.')} × #{dims_match[3].gsub(',', '.')}"
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Package dimensions from table: #{result[:package_dimensions]}"
            end
          end
        end
      end
      
      # Дополнительный поиск в тексте страницы (regex поиск)
      page_text = doc.text
      
      # Ищем вес в тексте (например, "Waga: 37.55 kg" или "37.55 kg")
      if result[:weight].blank?
        # Паттерн 1: "Waga: 37.55 kg" или "Waga 37.55 kg"
        page_text.scan(/(?:waga|weight|masa)[:\s]+([\d,\.]+)\s*(kg|кг)/i) do |match|
          weight_value = match[0].gsub(',', '.').to_f
          # Берем первый найденный вес в разумном диапазоне (5-100 кг)
          if weight_value >= 5 && weight_value <= 100
            result[:weight] = weight_value.round(2)
            Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Weight from page text (pattern 1): #{result[:weight]} kg"
            break
          end
        end
        
        # Паттерн 2: Первый найденный вес в разумном диапазоне (вес с упаковкой)
        if result[:weight].blank?
          # Ищем первый вес в разумном диапазоне для мебели (5-100 кг)
          page_text.scan(/([\d,\.]+)\s*kg/i) do |match|
            weight_value = match[0].gsub(',', '.').to_f
            # Берем первый найденный вес в разумном диапазоне (это вес с упаковкой)
            if weight_value >= 5 && weight_value <= 100
              result[:weight] = weight_value.round(2)
              Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Found package weight (first match): #{result[:weight]} kg"
              break
            end
          end
        end
      end
      
      # Ищем размеры упаковки в тексте (если еще не найдены)
      if result[:package_dimensions].blank?
        # Ищем в секции упаковки
        packaging_sections = doc.css('*').select { |el| 
          text = el.text.downcase
          text.include?('opakowanie') || text.include?('paczk')
        }
        
        packaging_sections.each do |section|
          section_text = section.text
          width = section_text.match(/szerokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
          height = section_text.match(/wysokość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
          length = section_text.match(/długość[:\s]+([\d,\.]+)\s*cm/i)&.captures&.first
          
          if width && height && length
            result[:package_dimensions] = "#{width.gsub(',', '.')} × #{height.gsub(',', '.')} × #{length.gsub(',', '.')} cm"
            Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Package dimensions from packaging section text: #{result[:package_dimensions]}"
            break
          end
        end
      end
      
      # Ищем размеры продукта в тексте (если еще не найдены)
      if result[:dimensions].blank?
        # Ищем в секции с размерами
        dimensions_sections = doc.css('*').select { |el| 
          text = el.text.downcase
          text.include?('wymiary') || text.include?('rozmiar')
        }
        
        dimensions_sections.each do |section|
          section_text = section.text
          width_match = section_text.match(/szerokość[:\s]+([\d,\.]+)\s*cm/i)
          depth_match = section_text.match(/głębokość[:\s]+([\d,\.]+)\s*cm/i)
          height_match = section_text.match(/wysokość[:\s]+([\d,\.]+)\s*cm/i)
          
          if width_match && depth_match
            dims = [
              width_match[1].gsub(',', '.'),
              depth_match[1].gsub(',', '.'),
              height_match&.captures&.first&.gsub(',', '.')
            ].compact.reject(&:empty?)
            result[:dimensions] = dims.join(' × ') + ' cm' if dims.any?
            Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Dimensions from dimensions section: #{result[:dimensions]}"
            break
          end
        end
        
        # Если не нашли в секциях, ищем по всей странице
        if result[:dimensions].blank?
          width_match = page_text.match(/szerokość[:\s]+([\d,\.]+)\s*cm/i)
          depth_match = page_text.match(/głębokość[:\s]+([\d,\.]+)\s*cm/i)
          height_match = page_text.match(/wysokość[:\s]+([\d,\.]+)\s*cm/i)
          
          if width_match && depth_match
            dims = [
              width_match[1].gsub(',', '.'),
              depth_match[1].gsub(',', '.'),
              height_match&.captures&.first&.gsub(',', '.')
            ].compact.reject(&:empty?)
            result[:dimensions] = dims.join(' × ') + ' cm' if dims.any?
            Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Dimensions from page text: #{result[:dimensions]}"
          end
        end
      end
      
      # Если размеры не найдены, пробуем извлечь из JSON-LD (если еще не сделали)
      if result[:dimensions].blank?
        doc.css('script[type="application/ld+json"]').each do |script|
          begin
            schema_data = JSON.parse(script.text)
            if schema_data['@type'] == 'Product'
              width = schema_data['width']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
              height = schema_data['height']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
              depth = schema_data['depth']&.to_s&.gsub(/\s*cm\s*/i, '')&.gsub(',', '.')
              
              if width && depth
                # Если height не указан в JSON-LD, ищем его в тексте страницы
                if height.blank? || height.empty?
                  height_match = page_text.match(/wysokość[:\s]+([\d,\.]+)\s*cm/i)
                  height = height_match&.captures&.first&.gsub(',', '.') if height_match
                end
                
                dims = [width, depth, height].compact.reject(&:empty?)
                result[:dimensions] = dims.join(' × ') + ' cm' if dims.any?
                Rails.logger.debug "PlDetailsFetcher.extract_packaging_info: Dimensions from JSON-LD: #{result[:dimensions]}"
                break
              end
            end
          rescue JSON::ParserError
            next
          end
        end
      end
    end
    
    Rails.logger.info "PlDetailsFetcher.extract_packaging_info: Extracted - weight: #{result[:weight]}, net_weight: #{result[:net_weight]}, volume: #{result[:package_volume]}, dimensions: #{result[:dimensions]}, package_dimensions: #{result[:package_dimensions]}"
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
    doc.css('a[href*="manual"], a[href*="instruction"], a[href*="assembly"]').each do |link|
      href = link['href']
      manuals << href if href.present?
    end
    
    manuals.uniq.compact
  end
  
  # Извлечение данных из модального окна с описанием продукта
  # Гибкий метод, который работает даже если модальное окно загружается через JS
  def extract_modal_details(doc)
    result = {}
    
    Rails.logger.debug "PlDetailsFetcher.extract_modal_details: Starting extraction"
    
    # Ищем модальное окно по разным селекторам (может быть скрыто или в HTML)
    modal_selectors = [
      '.pipf-product-details-modal',
      '[class*="product-details-modal"]',
      '[id*="product-details"]',
      '[aria-labelledby*="pip-modal-header"]',
      '[aria-modal="true"]',
      '.pipf-sheets',
      '[role="dialog"]'
    ]
    
    modal = nil
    modal_selectors.each do |selector|
      modal = doc.css(selector).first
      break if modal
    end
    
    # Если модальное окно не найдено, ищем данные в скриптах и по всему документу
    if modal.nil?
      Rails.logger.debug "PlDetailsFetcher.extract_modal_details: Modal not found in HTML, searching in scripts and document"
      # Ищем данные в скриптах (модальное окно может быть загружено через JS)
      extract_from_scripts(doc, result)
      modal = doc # Используем весь документ для поиска
    else
      Rails.logger.debug "PlDetailsFetcher.extract_modal_details: Found product details modal"
    end
    
    # Извлекаем описание продукта (все параграфы из модального окна)
    extract_description_from_modal(modal, result)
    
    # Извлекаем дизайнера
    extract_designer_from_modal(modal, doc, result)
    
    # Извлекаем материалы и инструкции по уходу из секции "Материалы и уход"
    extract_materials_and_care_from_modal(modal, doc, result)
    
    # Извлекаем информацию о безопасности
    extract_safety_info_from_modal(modal, result)
    
    # Извлекаем информацию "Полезно знать"
    extract_good_to_know_from_modal(modal, result)
    
    # Извлекаем ссылки на документы (инструкции по сборке и уходу)
    extract_documents_from_modal(modal, doc, result)
    
    Rails.logger.info "PlDetailsFetcher.extract_modal_details: Extracted - description: #{result[:description].present?}, materials: #{result[:materials].present?}, designer: #{result[:designer].present?}, documents: #{result[:assembly_documents]&.length || 0}"
    result
  end
  
  # Вспомогательные методы для извлечения данных из модального окна
  
  def extract_description_from_modal(modal, result)
    # Ищем все параграфы описания в модальном окне
    paragraphs = modal.css('.pipf-product-details-modal__paragraph').map(&:text).map(&:strip).compact.reject(&:empty?)
    
    # Фильтруем параграфы, которые похожи на описание продукта (не служебные)
    description_paragraphs = paragraphs.select { |p| 
      p.length > 30 && 
      !p.match?(/cookie|privacy|terms|regulamin|polityka|ikea\.com/i) &&
      !p.match?(/^\d+$/) # Не числа
    }
    
    if description_paragraphs.any?
      # Первый параграф - краткое описание, остальные - полное описание
      result[:short_description] = description_paragraphs.first if description_paragraphs.first.present?
      if description_paragraphs.length > 1
        result[:description] = description_paragraphs.join("\n\n")
      elsif description_paragraphs.length == 1
        result[:description] = description_paragraphs.first
      end
      Rails.logger.debug "PlDetailsFetcher.extract_description_from_modal: Extracted #{description_paragraphs.length} description paragraphs"
    end
  end
  
  def extract_designer_from_modal(modal, doc, result)
    # Ищем дизайнера в модальном окне
    # Структура: .pipf-product-details-modal__header содержит "Дизайнер", следующий .pipf-product-details-modal__label содержит имя
    modal.css('.pipf-product-details-modal__header').each do |header|
      header_text = header.text.strip.downcase
      if header_text.include?('дизайнер') || header_text.include?('designer') || header_text.include?('проектант') || header_text.include?('projektant')
        # Ищем следующий элемент с классом label
        label = header.parent.css('.pipf-product-details-modal__label').first || 
                header.next_element&.css('.pipf-product-details-modal__label')&.first ||
                header.parent.next_element&.css('.pipf-product-details-modal__label')&.first
        
        if label
          designer_value = label.text.strip
          if designer_value.present?
            result[:designer] = designer_value
            Rails.logger.debug "PlDetailsFetcher.extract_designer_from_modal: Found designer: #{result[:designer]}"
            return
          end
        end
      end
    end
    
    # Если не нашли, ищем в тексте страницы
    if result[:designer].blank?
      page_text = doc.text
      # Ищем имена дизайнеров IKEA (более полный список)
      designer_patterns = [
        /Maja\s+Ganszyniec/i,
        /Мая\s+Ганшинец/i,
        /IKEA\s+of\s+Sweden/i,
        /проектант[ка]?\s*:?\s*([А-ЯЁ][а-яё]+\s+[А-ЯЁ][а-яё]+)/i,
        /designer[:\s]+([A-Z][a-z]+\s+[A-Z][a-z]+)/i
      ]
      
      designer_patterns.each do |pattern|
        match = page_text.match(pattern)
        if match
          result[:designer] = match[1] || match[0]
          Rails.logger.debug "PlDetailsFetcher.extract_designer_from_modal: Found designer in page text: #{result[:designer]}"
          break
        end
      end
    end
  end
  
  def extract_materials_and_care_from_modal(modal, doc, result)
    # Ищем секцию "Материалы и уход" по разным селекторам
    materials_section = find_section_by_id(modal, 'product-details-material-and-care') ||
                        find_section_by_text(modal, ['материал', 'material', 'уход', 'care'])
    
    if materials_section
      # Извлекаем материалы
      materials_data = extract_materials_list(materials_section)
      if materials_data.any?
        result[:materials] = materials_data.join("\n")
        Rails.logger.debug "PlDetailsFetcher.extract_materials_and_care_from_modal: Extracted #{materials_data.length} material items"
      end
      
      # Извлекаем инструкции по уходу
      care_data = extract_care_instructions(materials_section)
      if care_data.any?
        result[:care_instructions] = care_data.join("\n")
        Rails.logger.debug "PlDetailsFetcher.extract_materials_and_care_from_modal: Extracted care instructions"
      end
    end
    
    # Если не нашли, ищем по всему документу
    if result[:materials].blank?
      extract_materials_from_document(doc, result)
    end
  end
  
  def extract_materials_list(section)
    materials_data = []
    
    # Ищем заголовок "Материалы"
    materials_header = section.css('h3, .pipf-product-details-modal__material-header, [class*="material-header"]').find { |h|
      text = h.text.downcase
      text.include?('материал') || text.include?('material')
    }
    
    return materials_data unless materials_header
    
    # Ищем все dl.pipf-product-details-modal__section элементы
    section.css('dl.pipf-product-details-modal__section, dl').each do |dl|
      dl.css('dt').each do |dt|
        dt_text = dt.text.strip
        next if dt_text.blank?
        
        # Ищем соответствующий dd элемент
        dd = find_next_dd(dt)
        dd_text = dd&.text&.strip if dd
        
        if dt_text.present? && dd_text.present?
          materials_data << "#{dt_text}: #{dd_text}"
        end
      end
    end
    
    # Если не нашли через dl, пробуем найти dt/dd напрямую в секции
    if materials_data.empty?
      section.css('dt').each do |dt|
        dt_text = dt.text.strip
        next if dt_text.blank?
        
        dd = find_next_dd(dt)
        dd_text = dd&.text&.strip if dd
        
        if dt_text.present? && dd_text.present?
          materials_data << "#{dt_text}: #{dd_text}"
        end
      end
    end
    
    materials_data
  end
  
  def find_next_dd(dt)
    # Ищем следующий dd элемент
    dd = dt.next_element
    while dd && dd.name != 'dd'
      dd = dd.next_element
    end
    
    # Если не нашли, пробуем найти в родительском элементе
    if dd.nil?
      parent = dt.parent
      if parent
        dt_index = parent.children.index(dt)
        if dt_index
          parent.children[dt_index + 1..-1].each do |sibling|
            if sibling.name == 'dd'
              dd = sibling
              break
            end
          end
        end
      end
    end
    
    dd
  end
  
  def extract_care_instructions(section)
    care_items = []
    
    # Ищем заголовок "Уход"
    care_header = section.css('h3, .pipf-product-details-modal__care-header, [class*="care-header"]').find { |h|
      text = h.text.downcase
      text.include?('уход') || text.include?('care')
    }
    
    return care_items unless care_header
    
    # Ищем все элементы после заголовка ухода
    care_section = care_header.parent || care_header.next_element
    
    # Извлекаем заголовки и метки
    care_section.css('.pipf-product-details-modal__header, .pipf-product-details-modal__label, p').each do |el|
      text = el.text.strip
      care_items << text if text.present? && text.length > 3 && !text.match?(/^\d+$/)
    end
    
    care_items
  end
  
  def extract_materials_from_document(doc, result)
    # Ищем все dt/dd пары в документе, которые могут быть материалами
    doc.css('dl, dt').each do |el|
      if el.name == 'dt'
        dt_text = el.text.strip.downcase
        # Проверяем, похоже ли это на описание материала
        material_keywords = ['каркас', 'ткань', 'frame', 'fabric', 'пружин', 'spring', 'ножка', 'leg', 'подушка', 'cushion', 'видеоролик', 'video']
        if material_keywords.any? { |keyword| dt_text.include?(keyword) }
          dd = find_next_dd(el)
          dd_text = dd&.text&.strip if dd
          
          if dt_text.present? && dd_text.present?
            result[:materials] ||= []
            result[:materials] = (result[:materials].is_a?(Array) ? result[:materials] : [result[:materials]]).push("#{el.text.strip}: #{dd_text}").join("\n")
            Rails.logger.debug "PlDetailsFetcher.extract_materials_from_document: Found material: #{el.text.strip}"
          end
        end
      end
    end
  end
  
  def extract_safety_info_from_modal(modal, result)
    safety_section = find_section_by_id(modal, 'product-details-safety-and-compliance') ||
                     find_section_by_text(modal, ['безопасность', 'safety', 'соответствие', 'compliance'])
    
    if safety_section
      safety_paragraphs = safety_section.css('.pipf-product-details-modal__paragraph, p, span.pipf-product-details-modal__paragraph').map(&:text).map(&:strip).compact.reject(&:empty?)
      if safety_paragraphs.any?
        result[:safety_info] = safety_paragraphs.join("\n\n")
        Rails.logger.debug "PlDetailsFetcher.extract_safety_info_from_modal: Extracted safety information"
      end
    end
  end
  
  def extract_good_to_know_from_modal(modal, result)
    good_to_know_section = find_section_by_id(modal, 'product-details-good-to-know') ||
                           find_section_by_text(modal, ['полезно знать', 'good to know', 'good-to-know'])
    
    if good_to_know_section
      good_to_know_paragraphs = good_to_know_section.css('.pipf-product-details-modal__paragraph, p').map(&:text).map(&:strip).compact.reject(&:empty?)
      if good_to_know_paragraphs.any?
        result[:good_to_know] = good_to_know_paragraphs.join("\n\n")
        Rails.logger.debug "PlDetailsFetcher.extract_good_to_know_from_modal: Extracted 'good to know' information"
      end
    end
  end
  
  def extract_documents_from_modal(modal, doc, result)
    assembly_section = find_section_by_id(modal, 'product-details-assembly-and-documents') ||
                       find_section_by_text(modal, ['сборка', 'assembly', 'документ', 'document'])
    
    document_links = []
    
    if assembly_section
      # Ищем все ссылки на документы
      assembly_section.css('.pipf-product-details-modal__document-link, a[href*="assembly_instructions"], a[href*="manuals"]').each do |link|
        href = link['href']
        text = link.text.strip.gsub(/\s+/, ' ')
        # Удаляем номер статьи из текста, если есть
        text = text.gsub(/\d{3}\.\d{3}\.\d{2}/, '').strip
        
        if href.present?
          document_links << { url: href, title: text.presence || 'Документ' }
        end
      end
    end
    
    # Ищем ссылки на документы в HTML исходнике (модальное окно может быть в HTML, но скрыто)
    if document_links.empty?
      doc.css('a[href*="assembly_instructions"], a[href*="manuals"]').each do |link|
        href = link['href']
        text = link.text.strip
        if href.present?
          document_links << { url: href, title: text.presence || 'Документ' }
        end
      end
    end
    
    if document_links.any?
      result[:assembly_documents] = document_links.uniq { |d| d[:url] }
      Rails.logger.debug "PlDetailsFetcher.extract_documents_from_modal: Extracted #{result[:assembly_documents].length} document links"
    end
  end
  
  # Вспомогательные методы для поиска секций
  
  def find_section_by_id(modal, id_pattern)
    # Ищем секцию по ID (точное совпадение или частичное)
    modal.css("[id*='#{id_pattern}'], [id='#{id_pattern}']").first
  end
  
  def find_section_by_text(modal, keywords)
    # Ищем секцию по тексту (заголовок содержит ключевые слова)
    modal.css('*').find do |el|
      text = el.text.downcase
      keywords.any? { |keyword| text.include?(keyword.downcase) } &&
      (el.css('h3, h2, [class*="header"]').any? || el['id']&.include?('product-details'))
    end
  end
  
  def extract_from_scripts(doc, result)
    # Ищем данные модального окна в скриптах (модальное окно может быть загружено через JS)
    doc.css('script').each do |script|
      script_text = script.text
      
      # Ищем JSON с данными о продукте
      if script_text.include?('product-details') || script_text.include?('materials') || script_text.include?('designer')
        begin
          # Пробуем найти JSON объекты
          json_matches = script_text.scan(/\{[^{}]*(?:"materials"|"designer"|"care"|"safety")[^{}]*\}/m)
          json_matches.each do |json_str|
            begin
              json_data = JSON.parse(json_str)
              result[:materials] ||= json_data['materials'] if json_data['materials']
              result[:designer] ||= json_data['designer'] if json_data['designer']
              result[:care_instructions] ||= json_data['care'] if json_data['care']
              result[:safety_info] ||= json_data['safety'] if json_data['safety']
            rescue JSON::ParserError
              next
            end
          end
        rescue => e
          Rails.logger.debug "PlDetailsFetcher.extract_from_scripts: Error parsing script: #{e.message}"
        end
      end
    end
    
    # Также ищем данные напрямую в HTML исходнике (модальное окно может быть в HTML, но скрыто)
    html_source = doc.to_html
    
    # Ищем материалы по ключевым словам из предоставленного HTML
    if result[:materials].blank? && (html_source.include?('Каркас сиденья') || html_source.include?('Ткань') || html_source.include?('Карманные пружины'))
      Rails.logger.debug "PlDetailsFetcher.extract_from_scripts: Found material keywords in HTML source, trying to extract"
      # Пробуем найти структуру dt/dd в HTML исходнике
      extract_materials_from_html_source(doc, result)
    end
    
    # Ищем инструкции по уходу
    if result[:care_instructions].blank? && (html_source.include?('Пылесосить') || html_source.include?('Протрите чистой влажной тканью'))
      Rails.logger.debug "PlDetailsFetcher.extract_from_scripts: Found care keywords in HTML source"
      extract_care_from_html_source(doc, result)
    end
    
    # Ищем информацию о безопасности
    if result[:safety_info].blank? && (html_source.include?('Износостойкость') || html_source.include?('светостойкостью'))
      Rails.logger.debug "PlDetailsFetcher.extract_from_scripts: Found safety keywords in HTML source"
      extract_safety_from_html_source(doc, result)
    end
    
    # Ищем "Полезно знать"
    if result[:good_to_know].blank? && (html_source.include?('Крышка прикреплена') || html_source.include?('IKEA в Швеции'))
      Rails.logger.debug "PlDetailsFetcher.extract_from_scripts: Found good-to-know keywords in HTML source"
      extract_good_to_know_from_html_source(doc, result)
    end
  end
  
  def extract_materials_from_html_source(doc, result)
    # Ищем все dt/dd пары, которые могут быть материалами
    materials_data = []
    
    # Ищем по ключевым словам из предоставленного HTML (на русском и польском)
    material_keywords = [
      'Каркас сиденья', 'Карманные пружины', 'Нижняя часть рамы', 'Подушка спинки',
      'Видеоролик', 'Ткань', 'Каркас', 'пружин', 'ножка', 'подушка', 'видеоролик',
      'Frame', 'Spring', 'Leg', 'Cushion', 'Fabric',
      'Rama', 'Sprężyny', 'Noga', 'Poduszka', 'Tkanina', 'Materiał'
    ]
    
    # Ищем все dt элементы
    doc.css('dt').each do |dt_elem|
      dt_text = dt_elem.text.strip
      next if dt_text.blank?
      
      # Проверяем, содержит ли dt ключевые слова
      if material_keywords.any? { |keyword| dt_text.include?(keyword) }
        # Ищем соответствующий dd
        dd = find_next_dd(dt_elem)
        dd_text = dd&.text&.strip if dd
        
        if dt_text.present? && dd_text.present?
          materials_data << "#{dt_text}: #{dd_text}"
        end
      end
    end
    
    # Если не нашли через dt, ищем по тексту в HTML исходнике (более агрессивный поиск)
    if materials_data.empty?
      html_text = doc.text
      # Ищем известные пары из предоставленного HTML (на русском)
      known_materials_patterns = [
        [/Каркас\s+сиденья[:\s]+(.+?)(?:\n|Карманные|$)/i, 'Каркас сиденья'],
        [/Карманные\s+пружины[:\s]+(.+?)(?:\n|Нижняя|$)/i, 'Карманные пружины'],
        [/Нижняя\s+часть\s+рамы[:\s]+(.+?)(?:\n|Подушка|$)/i, 'Нижняя часть рамы/нога'],
        [/Подушка\s+спинки[:\s]+(.+?)(?:\n|Видеоролик|$)/i, 'Подушка спинки'],
        [/Видеоролик[:\s]+(.+?)(?:\n|Ткань|$)/i, 'Видеоролик'],
        [/Ткань[:\s]+(.+?)(?:\n|$)/i, 'Ткань']
      ]
      
      known_materials_patterns.each do |pattern, label|
        match = html_text.match(pattern)
        if match && match[1]
          value = match[1].strip
          if value.length > 5 && value.length < 500
            materials_data << "#{label}: #{value}"
          end
        end
      end
    end
    
    if materials_data.any?
      result[:materials] = materials_data.join("\n")
      Rails.logger.debug "PlDetailsFetcher.extract_materials_from_html_source: Extracted #{materials_data.length} materials from HTML source"
    end
  end
  
  def extract_care_from_html_source(doc, result)
    care_items = []
    
    # Ищем элементы с текстом об уходе
    care_keywords = ['Пылесосить', 'Протрите', 'чистой влажной тканью', 'Vacuum', 'Wipe', 'clean damp cloth', 'Odkurz', 'Przetrzyj']
    
    doc.css('p, span, [class*="label"]').each do |el|
      text = el.text.strip
      if care_keywords.any? { |keyword| text.include?(keyword) } && text.length > 5
        care_items << text
      end
    end
    
    # Если не нашли, ищем по тексту в HTML исходнике
    if care_items.empty?
      html_text = doc.text
      care_patterns = [
        /Рамка[^,]*,\s*несъемная\s+крышка[:\s]*\n*(.+?)(?:\n|Износостойкость|$)/i,
        /Пылесосить[\.]?\s*(.+?)(?:\n|Протрите|$)/i,
        /Протрите\s+чистой\s+влажной\s+тканью[\.]?\s*(.+?)(?:\n|$)/i
      ]
      
      care_patterns.each do |pattern|
        match = html_text.match(pattern)
        if match && match[1]
          value = match[1].strip
          care_items << value if value.length > 3 && value.length < 200
        end
      end
      
      # Также ищем известные фразы
      if html_text.include?('Пылесосить')
        care_items << 'Пылесосить.'
      end
      if html_text.include?('Протрите чистой влажной тканью')
        care_items << 'Протрите чистой влажной тканью.'
      end
    end
    
    if care_items.any?
      result[:care_instructions] = care_items.uniq.join("\n")
      Rails.logger.debug "PlDetailsFetcher.extract_care_from_html_source: Extracted care instructions from HTML source"
    end
  end
  
  def extract_safety_from_html_source(doc, result)
    safety_paragraphs = []
    
    # Ищем элементы с информацией о безопасности
    safety_keywords = ['Износостойкость', 'светостойкостью', 'испытания', 'стандартам', 'Wear resistance', 'lightfastness', 'tested', 'Wytrzymałość', 'odporność']
    
    doc.css('p, span, [class*="paragraph"]').each do |el|
      text = el.text.strip
      if safety_keywords.any? { |keyword| text.include?(keyword) } && text.length > 50
        safety_paragraphs << text
      end
    end
    
    # Если не нашли, ищем по тексту в HTML исходнике
    if safety_paragraphs.empty?
      html_text = doc.text
      safety_patterns = [
        /Износостойкость\s+этой\s+ткани\s+протестирована\s+на\s+(\d+)\s+циклов[\.]?\s*(.+?)(?:\n|Покрытие|$)/i,
        /Покрытие\s+обладает\s+светостойкостью\s+(\d+)[\.]?\s*(.+?)(?:\n|Данное|$)/i,
        /Данное\s+сиденье\s+прошло\s+испытания[\.]?\s*(.+?)(?:\n|$)/i
      ]
      
      safety_patterns.each do |pattern|
        match = html_text.match(pattern)
        if match
          if match[2]
            safety_paragraphs << match[0].strip
          elsif match[1]
            safety_paragraphs << match[0].strip
          end
        end
      end
    end
    
    if safety_paragraphs.any?
      result[:safety_info] = safety_paragraphs.uniq.join("\n\n")
      Rails.logger.debug "PlDetailsFetcher.extract_safety_from_html_source: Extracted safety info from HTML source"
    end
  end
  
  def extract_good_to_know_from_html_source(doc, result)
    good_to_know_paragraphs = []
    
    # Ищем элементы с информацией "Полезно знать"
    good_to_know_keywords = ['Крышка прикреплена', 'IKEA в Швеции', 'Cover attached', 'IKEA Sweden', 'Pokrywa przymocowana', 'IKEA Szwecja']
    
    doc.css('p, span, [class*="paragraph"]').each do |el|
      text = el.text.strip
      if good_to_know_keywords.any? { |keyword| text.include?(keyword) } && text.length > 10
        good_to_know_paragraphs << text
      end
    end
    
    # Если не нашли, ищем по тексту в HTML исходнике
    if good_to_know_paragraphs.empty?
      html_text = doc.text
      good_to_know_patterns = [
        /Крышка\s+прикреплена\s+намертво[\.]?\s*(.+?)(?:\n|IKEA|$)/i,
        /IKEA\s+в\s+Швеции\s+AB[\.]?\s*(.+?)(?:\n|$)/i
      ]
      
      good_to_know_patterns.each do |pattern|
        match = html_text.match(pattern)
        if match
          if match[1]
            good_to_know_paragraphs << match[0].strip
          else
            good_to_know_paragraphs << match[0].strip
          end
        end
      end
      
      # Также ищем известные фразы
      if html_text.include?('Крышка прикреплена намертво')
        good_to_know_paragraphs << 'Крышка прикреплена намертво.'
      end
      if html_text.include?('IKEA в Швеции')
        good_to_know_paragraphs << html_text.match(/IKEA\s+в\s+Швеции[^\.]+\./i)&.to_s
      end
    end
    
    if good_to_know_paragraphs.any?
      result[:good_to_know] = good_to_know_paragraphs.compact.uniq.join("\n\n")
      Rails.logger.debug "PlDetailsFetcher.extract_good_to_know_from_html_source: Extracted good-to-know from HTML source"
    end
  end
  
  # Извлечение информации о наличии из HTML
  def extract_availability(doc, product_data)
    availability = {}
    
    # Из productData
    if product_data
      stock_info = product_data.dig('stockcheckSection') || product_data.dig('stock') || product_data.dig('availability')
      if stock_info
        if stock_info.is_a?(Hash)
          quantity = stock_info['quantity'] || stock_info['availableQuantity'] || stock_info['stock']
          availability[:quantity] = quantity.to_i if quantity
          availability[:status] = stock_info['status'] || stock_info['availabilityStatus']
        end
      end
    end
    
    # Из HTML - ищем текст о наличии
    doc.css('[data-availability], [data-stock], .availability, .stock-status').each do |elem|
      text = elem.text.downcase
      if text.include?('dostępn') || text.include?('w magazynie') || text.include?('available')
        # Пробуем извлечь количество
        quantity_match = text.match(/(\d+)\s*(szt|sztuk|item|items)/i)
        if quantity_match
          availability[:quantity] = quantity_match[1].to_i
        else
          # Если просто "dostępne", ставим большое число
          availability[:quantity] = 999 if text.include?('dostępn')
        end
        availability[:status] = 'available'
      elsif text.include?('niedostępn') || text.include?('out of stock')
        availability[:quantity] = 0
        availability[:status] = 'unavailable'
      end
    end
    
    # Ищем в тексте страницы
    page_text = doc.text.downcase
    if page_text.include?('dostępne z dostawą') || page_text.include?('dostępny w')
      availability[:quantity] ||= 999
      availability[:status] ||= 'available'
    end
    
    availability
  end
  
  # Извлечение описания продукта и расширенных атрибутов (улучшенная версия на основе JS-парсера)
  def extract_product_description(doc, product_data)
    result = {}
    
    Rails.logger.debug "PlDetailsFetcher.extract_product_description: Starting extraction"
    
    # Описание из productData - расширенный список путей
    if product_data
      # Пути для описания
      description_paths = [
        ['productInformationSection', 'description'],
        ['productInformationSection', 'text'],
        ['productInformationSection', 'fullDescription'],
        ['productDescription'],
        ['description'],
        ['productDetails', 'description'],
        ['productDetails', 'text'],
        ['product', 'description'],
        ['product', 'text'],
        ['details', 'description'],
        ['details', 'text']
      ]
      
      description_paths.each do |path|
        desc = product_data.dig(*path)
        if desc.present?
          result[:description] = desc.is_a?(String) ? desc : desc.to_json
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found description in #{path.join('.')}"
          break
        end
      end
      
      # Пути для краткого описания
      short_desc_paths = [
        ['productInformationSection', 'shortDescription'],
        ['productInformationSection', 'summary'],
        ['shortDescription'],
        ['summary'],
        ['productDetails', 'shortDescription'],
        ['productDetails', 'summary']
      ]
      
      short_desc_paths.each do |path|
        short_desc = product_data.dig(*path)
        if short_desc.present?
          result[:short_description] = short_desc.is_a?(String) ? short_desc : short_desc.to_json
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found short_description in #{path.join('.')}"
          break
        end
      end
      
      # Материалы - расширенный поиск
      materials_paths = [
        ['productInformationSection', 'materials'],
        ['productInformationSection', 'materialInfo'],
        ['productInformationSection', 'materials', 'text'],
        ['productInformationSection', 'materials', 'items'],
        ['materials'],
        ['materialInfo'],
        ['productDetails', 'materials'],
        ['productDetails', 'materialInfo']
      ]
      
      materials_paths.each do |path|
        materials = product_data.dig(*path)
        if materials.present?
          # Если это массив, преобразуем в строку
          if materials.is_a?(Array)
            result[:materials] = materials.map { |m| m.is_a?(Hash) ? (m['text'] || m['name'] || m.to_s) : m.to_s }.join("\n")
          elsif materials.is_a?(Hash)
            result[:materials] = materials['text'] || materials['name'] || materials.to_json
          else
            result[:materials] = materials.to_s
          end
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found materials in #{path.join('.')}"
          break
        end
      end
      
      # Характеристики (features) - расширенный поиск
      features_paths = [
        ['productInformationSection', 'features'],
        ['productInformationSection', 'characteristics'],
        ['productInformationSection', 'features', 'items'],
        ['productInformationSection', 'features', 'text'],
        ['features'],
        ['characteristics'],
        ['productDetails', 'features'],
        ['productDetails', 'characteristics']
      ]
      
      features_paths.each do |path|
        features = product_data.dig(*path)
        if features.present?
          # Если это массив, сохраняем как массив
          if features.is_a?(Array)
            result[:features] = features.map { |f| f.is_a?(Hash) ? (f['text'] || f['name'] || f.to_s) : f.to_s }
          elsif features.is_a?(Hash)
            # Если это объект с items или text
            if features['items'].is_a?(Array)
              result[:features] = features['items'].map { |f| f.is_a?(Hash) ? (f['text'] || f['name'] || f.to_s) : f.to_s }
            elsif features['text'].present?
              result[:features] = [features['text']]
            else
              result[:features] = [features.to_json]
            end
          else
            result[:features] = [features.to_s]
          end
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found features in #{path.join('.')}"
          break
        end
      end
      
      # Инструкции по уходу
      care_paths = [
        ['productInformationSection', 'careInstructions'],
        ['productInformationSection', 'care', 'instructions'],
        ['careInstructions'],
        ['care', 'instructions'],
        ['productDetails', 'careInstructions']
      ]
      
      care_paths.each do |path|
        care = product_data.dig(*path)
        if care.present?
          if care.is_a?(Array)
            result[:care_instructions] = care.map { |c| c.is_a?(Hash) ? (c['text'] || c['name'] || c.to_s) : c.to_s }.join("\n")
          elsif care.is_a?(Hash)
            result[:care_instructions] = care['text'] || care['name'] || care.to_json
          else
            result[:care_instructions] = care.to_s
          end
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found care_instructions in #{path.join('.')}"
          break
        end
      end
      
      # Экологическая информация
      env_paths = [
        ['productInformationSection', 'environmentalInformation'],
        ['productInformationSection', 'environmentalInfo'],
        ['productInformationSection', 'environment', 'info'],
        ['environmentalInformation'],
        ['environmentalInfo'],
        ['environment', 'info'],
        ['productDetails', 'environmentalInformation']
      ]
      
      env_paths.each do |path|
        env_info = product_data.dig(*path)
        if env_info.present?
          if env_info.is_a?(Array)
            result[:environmental_info] = env_info.map { |e| e.is_a?(Hash) ? (e['text'] || e['name'] || e.to_s) : e.to_s }.join("\n")
          elsif env_info.is_a?(Hash)
            result[:environmental_info] = env_info['text'] || env_info['name'] || env_info.to_json
          else
            result[:environmental_info] = env_info.to_s
          end
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found environmental_info in #{path.join('.')}"
          break
        end
      end
    end
    
    # Извлечение из HTML (fallback)
    # Описание
    if result[:description].blank?
      description_selectors = [
        '.pip-product-information',
        '.pip-product-description',
        '.product-description',
        '[data-product-description]',
        '.pip-product-details-content',
        '.pip-overview__description',
        '.pip-product-details__description'
      ]
      
      description_selectors.each do |selector|
        desc_elem = doc.css(selector).first
        if desc_elem
          result[:description] = desc_elem.inner_html.strip
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found description in HTML selector: #{selector}"
          break if result[:description].present?
        end
      end
    end
    
    # Краткое описание
    if result[:short_description].blank?
      short_desc_selectors = [
        '.pip-header-section__description',
        '.pip-overview__short-description',
        '.product-short-description',
        '[data-short-description]'
      ]
      
      short_desc_selectors.each do |selector|
        short_desc_elem = doc.css(selector).first
        if short_desc_elem
          result[:short_description] = short_desc_elem.inner_html.strip
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found short_description in HTML selector: #{selector}"
          break if result[:short_description].present?
        end
      end
    end
    
    # Материалы из HTML
    if result[:materials].blank?
      materials_selectors = [
        '#materials-details',
        '.pip-materials',
        '[data-materials]',
        '.pip-product-details__materials',
        '.product-materials'
      ]
      
      materials_selectors.each do |selector|
        materials_elem = doc.css(selector).first
        if materials_elem
          result[:materials] = materials_elem.inner_html.strip
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found materials in HTML selector: #{selector}"
          break if result[:materials].present?
        end
      end
    end
    
    # Характеристики из HTML
    if result[:features].blank?
      features_selectors = [
        '.pip-product-features li',
        '.product-features li',
        '[data-feature]',
        '.pip-characteristics li',
        '.product-characteristics li'
      ]
      
      features_selectors.each do |selector|
        features_elems = doc.css(selector)
        if features_elems.any?
          result[:features] = features_elems.map(&:text).map(&:strip).compact.reject(&:empty?)
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found #{result[:features].length} features in HTML selector: #{selector}"
          break if result[:features].any?
        end
      end
    end
    
    # Инструкции по уходу из HTML
    if result[:care_instructions].blank?
      care_selectors = [
        '.pip-care-instructions__text',
        '.pip-care-instructions',
        '.care-instructions',
        '[data-care-instructions]'
      ]
      
      care_selectors.each do |selector|
        care_elem = doc.css(selector).first
        if care_elem
          result[:care_instructions] = care_elem.inner_html.strip
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found care_instructions in HTML selector: #{selector}"
          break if result[:care_instructions].present?
        end
      end
    end
    
    # Экологическая информация из HTML
    if result[:environmental_info].blank?
      env_selectors = [
        '.pip-environmental-info__text',
        '.pip-environmental-information',
        '.environmental-info',
        '[data-environmental-info]'
      ]
      
      env_selectors.each do |selector|
        env_elem = doc.css(selector).first
        if env_elem
          result[:environmental_info] = env_elem.inner_html.strip
          Rails.logger.debug "PlDetailsFetcher.extract_product_description: Found environmental_info in HTML selector: #{selector}"
          break if result[:environmental_info].present?
        end
      end
    end
    
    Rails.logger.info "PlDetailsFetcher.extract_product_description: Extracted - description: #{result[:description].present?}, short_description: #{result[:short_description].present?}, materials: #{result[:materials].present?}, features: #{result[:features].present?}, care_instructions: #{result[:care_instructions].present?}, environmental_info: #{result[:environmental_info].present?}"
    result.compact
  end
  
  def extract_images(doc, product_data, existing_images = [])
    images = existing_images.dup || []
    initial_count = images.length
    
    Rails.logger.debug "PlDetailsFetcher.extract_images: Starting with #{initial_count} existing images"
    
    # Из productData (data-hydration-props)
    if product_data
      Rails.logger.debug "PlDetailsFetcher.extract_images: product_data present, searching for images..."
      
      # Ищем изображения в различных секциях productData
      image_paths = [
        product_data.dig('mediaSection', 'images'),
        product_data.dig('productMedia', 'images'),
        product_data.dig('gallery', 'images'),
        product_data.dig('productImages'),
        product_data.dig('images'),
        product_data.dig('product', 'images'),
        product_data.dig('productData', 'images'),
        product_data.dig('productMediaSection', 'images'),
        product_data.dig('media', 'images')
      ]
      
      image_paths.each_with_index do |img_data, idx|
        next unless img_data
        
        Rails.logger.debug "PlDetailsFetcher.extract_images: Found image data at path #{idx}: #{img_data.class}"
        
        if img_data.is_a?(Array)
          img_data.each do |img|
            url = img.is_a?(Hash) ? (img['url'] || img['src'] || img['imageUrl'] || img['href'] || img['image']) : img
            if url.present? && url.is_a?(String)
              images << url
              Rails.logger.debug "PlDetailsFetcher.extract_images: Added image from array: #{url[0..100]}"
            end
          end
        elsif img_data.is_a?(Hash)
          url = img_data['url'] || img_data['src'] || img_data['imageUrl'] || img_data['href'] || img_data['image']
          if url.present?
            images << url
            Rails.logger.debug "PlDetailsFetcher.extract_images: Added image from hash: #{url[0..100]}"
          end
        end
      end
      
      # Ищем в variants
      variants = product_data.dig('gprDescription', 'variants') || product_data.dig('variants')
      if variants.is_a?(Array)
        Rails.logger.debug "PlDetailsFetcher.extract_images: Found #{variants.length} variants"
        variants.each do |variant|
          if variant.is_a?(Hash)
            img_url = variant['imageUrl'] || variant['image'] || variant['url'] || variant['src']
            if img_url.present?
              images << img_url
              Rails.logger.debug "PlDetailsFetcher.extract_images: Added image from variant: #{img_url[0..100]}"
            end
          end
        end
      end
    else
      Rails.logger.debug "PlDetailsFetcher.extract_images: product_data is nil"
    end
    
    # Из HTML - все изображения продукта (расширенный поиск)
    html_selectors = [
      '.pip-media img',
      '.pip-product-image img',
      '.product-image img',
      '[data-product-image] img',
      '.pip-gallery img',
      '.pip-product-compact__image',
      '.pip-product-compact img',
      '.pip-image img',
      'img[src*="ikea"]',
      '.product-gallery img'
    ]
    
    html_images_found = 0
    html_selectors.each do |selector|
      doc.css(selector).each do |img|
        src = img['src'] || img['data-src'] || img['data-lazy-src'] || img['data-original'] || img['data-image']
        if src.present?
          # Преобразуем относительные URL в абсолютные
          src = "https://www.ikea.com#{src}" if src.start_with?('/')
          images << src
          html_images_found += 1
        end
      end
    end
    Rails.logger.debug "PlDetailsFetcher.extract_images: Found #{html_images_found} images from HTML"
    
    # Также ищем в data-атрибутах
    doc.css('[data-image-url], [data-image-src], [data-product-image], [data-src]').each do |el|
      img_url = el['data-image-url'] || el['data-image-src'] || el['data-product-image'] || el['data-src']
      if img_url.present?
        img_url = "https://www.ikea.com#{img_url}" if img_url.start_with?('/')
        images << img_url
      end
    end
    
    # Убираем дубликаты и пустые значения, нормализуем URL
    images = images.compact.uniq.map do |url|
      next unless url.present? && url.is_a?(String)
      
      # Убираем параметры размера из URL IKEA (например, ?f=s, ?f=xl)
      normalized = url.split('?').first
      
      # Пропускаем маленькие иконки и placeholder изображения
      next if normalized.include?('placeholder') || normalized.include?('icon') || normalized.include?('logo')
      
      normalized
    end.compact.uniq
    
    Rails.logger.info "PlDetailsFetcher.extract_images: Extracted #{images.length} total images (#{initial_count} existing + #{images.length - initial_count} new)"
    images
  end
end

