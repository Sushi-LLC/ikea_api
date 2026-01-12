# Задача для парсинга продуктов
class ParseProductsJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, category_id: nil, task_id: nil)
    # Если task_id передан, используем существующую задачу, иначе создаем новую
    task = task_id ? ParserTask.find(task_id) : create_parser_task('products', limit: limit)
    
    # Проверяем, не остановлена ли задача перед началом выполнения
    check_task_not_stopped!(task)
    
    task.mark_as_running!
    
    notify_started('products', limit: limit)
    start_time = Time.current
    
    stats = {
      processed: 0,
      created: 0,
      updated: 0,
      errors: 0
    }
    
    begin
      categories = if category_id
                     Category.where(ikea_id: category_id)
                   else
                     Category.not_deleted
                   end
      
      categories_count = categories.count
      Rails.logger.info "ParseProductsJob: Found #{categories_count} categories to process"
      
      if categories_count == 0
        Rails.logger.warn "ParseProductsJob: No categories found. Task will complete with 0 processed items."
      end
      
      categories.find_each do |category|
        break if limit && stats[:processed] >= limit
        
        # Проверяем, не остановлена ли задача
        check_task_not_stopped!(task)
        
        Rails.logger.info "ParseProductsJob: Processing category #{category.name} (ID: #{category.ikea_id})"
        process_category_products(category, task, stats, limit)
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('products', stats)
      
      # Примечание: Картинки и расширенные атрибуты загружаются отдельными задачами:
      # - DownloadProductImagesJob - для загрузки картинок
      # - FetchProductExtendedAttributesJob - для расширенных атрибутов
      
    rescue StandardError => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "ParseProductsJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "ParseProductsJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('products', e)
      # Не пробрасываем ошибку дальше, чтобы задача была помечена как failed
    rescue => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "ParseProductsJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "ParseProductsJob unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!("Unexpected error: #{e.message}")
      notify_error('products', e)
    end
  end

  private

  def process_category_products(category, task, stats, limit)
    offset = 0
    page_size = 50
    max_retries = 3
    retry_count = 0
    
    Rails.logger.info "ParseProductsJob: Starting to fetch products for category #{category.ikea_id} (#{category.name})"
    
    # Проверяем, есть ли уже продукты в категории
    has_existing_products = category.has_products?
    is_uuid_category = category.uuid_id? || category.ikea_id.to_s.include?('/')
    proxy_list = ENV.fetch('PROXY_LIST', '').split(',').map(&:strip).reject(&:empty?)
    
    # Проверяем возможность обработки UUID категорий
    if is_uuid_category && proxy_list.empty? && !category.url.present?
      Rails.logger.warn "ParseProductsJob: Skipping UUID category #{category.ikea_id} (#{category.name}) - requires proxy for HTML parsing, but PROXY_LIST is empty and no URL"
      return # Пропускаем категорию без ошибки
    end
    
    loop do
      break if limit && stats[:processed] >= limit
      
      begin
        products_data = []
        
        # ВАЖНО: Используем ВСЕ доступные стратегии для максимального покрытия
        # Как в rake-задачах - пробуем все методы последовательно
        all_strategies = CategoryProductsSearchService::STRATEGIES
        
        Rails.logger.info "ParseProductsJob: Using ALL strategies for category #{category.ikea_id} (#{category.name}): #{all_strategies.join(', ')}"
        
        # Для категорий с числовыми ID используем все стратегии
        if !is_uuid_category
          products_data = CategoryProductsSearchService.search(
            category,
            offset: offset,
            limit: page_size,
            strategies: all_strategies
          )
        else
          # Для UUID категорий используем HTML парсинг и поиск через дочерние категории
          strategies_for_uuid = [:html_parsing, :children_categories, :api_by_category_name]
          products_data = CategoryProductsSearchService.search(
            category,
            offset: offset,
            limit: page_size,
            strategies: strategies_for_uuid
          )
        end
        
        # Если не нашли продукты через CategoryProductsSearchService, пробуем напрямую
        if products_data.empty? && category.url.present?
          Rails.logger.info "ParseProductsJob: Trying direct HTML parsing for category #{category.ikea_id}"
          products_data = CategoryProductsFetcher.fetch(
            category.url,
            offset: offset,
            limit: page_size
          )
        end
        
        # Если не нашли продукты, пробуем retry
        if products_data.empty? && retry_count < max_retries
          retry_count += 1
          Rails.logger.info "ParseProductsJob: Retry #{retry_count}/#{max_retries} for category #{category.name}"
          sleep(2)
          redo
        end
        
        Rails.logger.info "ParseProductsJob: Fetched #{products_data.length} products for category #{category.name} (ID: #{category.ikea_id}, offset: #{offset})"
        
        # Логируем метрики для категорий без продуктов
        if !has_existing_products && products_data.any?
          Rails.logger.info "ParseProductsJob: SUCCESS - Found #{products_data.length} products for previously empty category #{category.ikea_id} (#{category.name})"
        end
        
        # Если не нашли продукты после всех попыток, логируем и выходим
        if products_data.empty?
          if offset == 0
            Rails.logger.warn "ParseProductsJob: No products found for category #{category.name} (ID: #{category.ikea_id}) after all attempts"
            Rails.logger.warn "ParseProductsJob: Category details - has_url: #{category.url.present?}, numeric_id: #{category.numeric_id?}, uuid_id: #{category.uuid_id?}"
          end
          break
        end
        
        retry_count = 0 # Сбрасываем счетчик при успехе
        
        # Батчинг запросов наличия: собираем все item_no и делаем один запрос
        item_nos = products_data.map do |pd|
          # Используем ту же логику, что и в process_product
          pd['itemNoGlobal'] || pd[:itemNoGlobal] || 
          pd['itemNo'] || pd[:itemNo] || 
          pd['item_no'] || pd[:item_no] ||
          pd.dig('gprDescription', 'itemNo')
        end.compact.uniq
        
        availability_data = {}
        if item_nos.any?
          begin
            Rails.logger.info "ParseProductsJob: Batch fetching availability for #{item_nos.length} items"
            availability_data = IkeaApiService.check_availability(item_nos)
            Rails.logger.info "ParseProductsJob: Received availability data for #{availability_data.keys.length} items"
          rescue => e
            Rails.logger.error("ParseProductsJob: Failed to batch fetch availability: #{e.message}")
            # Продолжаем без данных наличия
          end
        end
        
        products_data.each do |product_data|
          break if limit && stats[:processed] >= limit
          
          # Проверяем статус задачи в каждой итерации
          check_task_not_stopped!(task)
          
          begin
            result = process_product(product_data, category, availability_data)
            stats[:created] += 1 if result[:created]
            stats[:updated] += 1 if result[:updated]
            stats[:processed] += 1
            task.increment_processed!
          rescue => e
            Rails.logger.error "Error processing product #{product_data['id']}: #{e.message}"
            stats[:errors] += 1
            task.increment_errors!
          end
        end
        
        offset += page_size
        break if products_data.length < page_size
        
      rescue => e
        # Обработка ошибок с retry логикой
        error_message = e.message.to_s
        is_proxy_error = error_message.include?('403 Forbidden') || error_message.include?('no proxies configured')
        
        if is_uuid_category && is_proxy_error
          Rails.logger.warn "ParseProductsJob: Skipping UUID category #{category.ikea_id} (#{category.name}) - requires proxy: #{error_message}"
          break # Пропускаем без инкремента ошибок
        elsif retry_count < max_retries
          retry_count += 1
          Rails.logger.warn "ParseProductsJob: Error fetching products for category #{category.ikea_id} (attempt #{retry_count}/#{max_retries}): #{e.message}"
          sleep(2) # Небольшая задержка перед повтором
          redo
        else
          Rails.logger.error "ParseProductsJob: Failed to fetch products for category #{category.ikea_id} (#{category.name}) after #{max_retries} attempts: #{e.message}"
          stats[:errors] += 1
          task.increment_errors!
          break
        end
      end
    end
  end

  def process_product(product_data, category, availability_data = {})
    # Нормализуем данные: CategoryProductsFetcher возвращает символьные ключи, API - строковые
    # Преобразуем в Hash с indifferent access для удобства
    if product_data.is_a?(Hash)
      normalized = {}
      product_data.each { |k, v| normalized[k.to_s] = v }
      product_data = normalized
    end
    
    # Поддержка разных форматов данных (API и CategoryProductsFetcher)
    sku = product_data['id'] || product_data[:id] || product_data['sku'] || product_data[:sku]
    return { created: false, updated: false } unless sku.present?
    
    product = Product.find_by(sku: sku)
    
    # URL может быть в разных полях
    pip_url = product_data['pipUrl'] || product_data[:pipUrl] || product_data['url'] || product_data[:url] || ''
    url = pip_url.start_with?('http') ? pip_url : "https://www.ikea.com#{pip_url}"
    
    # item_no может быть в разных полях
    item_no = product_data['itemNoGlobal'] || product_data[:itemNoGlobal] || 
              product_data['itemNo'] || product_data[:itemNo] || 
              product_data['item_no'] || product_data[:item_no]
    
    # name может быть в разных полях
    name = product_data['typeName'] || product_data[:typeName] || 
           product_data['name'] || product_data[:name]
    
    Rails.logger.info "ParseProductsJob: Processing product SKU=#{sku}, item_no=#{item_no}, name=#{name}, url=#{url}"
    
    # Базовые атрибуты из API поиска или CategoryProductsFetcher
    # Поддержка разных форматов данных
    images = if product_data.dig('gprDescription', 'variants')
               product_data.dig('gprDescription', 'variants')&.map { |v| v['imageUrl'] || v[:imageUrl] }&.compact || []
             elsif product_data['imageUrl'] || product_data[:imageUrl]
               # CategoryProductsFetcher возвращает одно изображение в imageUrl
               [product_data['imageUrl'] || product_data[:imageUrl]].compact
             elsif product_data['images'] || product_data[:images]
               Array(product_data['images'] || product_data[:images])
             else
               []
             end
    
    # Цена может быть в разных форматах (ОБЯЗАТЕЛЬНОЕ ПОЛЕ)
    price = product_data.dig('salesPrice', 'numeral') || 
            product_data.dig(:salesPrice, :numeral) ||
            product_data.dig('salesPrice', :numeral) ||
            product_data.dig(:salesPrice, 'numeral') ||
            product_data.dig('price', 'numeral') || 
            product_data.dig(:price, :numeral) ||
            product_data['price'] || 
            product_data[:price] ||
            product_data.dig('gprDescription', 'salesPrice', 'numeral') ||
            product_data.dig('gprDescription', 'price', 'numeral')
    
    # Преобразуем цену в число, если это строка
    if price.is_a?(String)
      price = price.gsub(/[^\d,.]/, '').gsub(',', '.').to_f
    end
    
    # Если цена не найдена, логируем предупреждение
    if price.blank? || price.to_f == 0
      Rails.logger.warn "ParseProductsJob: Product #{sku} has no price or price is 0"
    end
    
    # Извлекаем флаги isBestseller и isPopular из API ответа
    is_bestseller = product_data['isBestseller'] || 
                    product_data['is_bestseller'] || 
                    product_data[:isBestseller] || 
                    product_data[:is_bestseller] || 
                    product_data['bestseller'] || 
                    product_data[:bestseller] || 
                    false
    
    is_popular = product_data['isPopular'] || 
                 product_data['is_popular'] || 
                 product_data[:isPopular] || 
                 product_data[:is_popular] || 
                 product_data['popular'] || 
                 product_data[:popular] || 
                 false
    
    # Логируем найденные флаги для отладки
    if is_bestseller || is_popular
      Rails.logger.debug "ParseProductsJob: Product #{sku} - is_bestseller: #{is_bestseller}, is_popular: #{is_popular}"
    end
    
    attributes = {
      sku: sku,
      name: name,
      item_no: item_no,
      url: url,
      # Цена: из разных источников (обязательное поле)
      price: price,
      home_delivery: product_data['homeDelivery'] || product_data[:home_delivery],
      category_id: category.ikea_id,
      # Изображения: из разных источников (обязательное поле, загружаются сразу после сохранения)
      images: images,
      variants: product_data.dig('gprDescription', 'variants') || product_data[:variants] || product_data['variants'] || [],
      # Флаги популярности и хитов продаж из API
      is_bestseller: is_bestseller,
      is_popular: is_popular
    }
    
    Rails.logger.debug "ParseProductsJob: Base attributes for #{sku}: price=#{price}, images_count=#{images.length}"
    
    # Примечание: Расширенные атрибуты и загрузка картинок вынесены в отдельные задачи:
    # - FetchProductExtendedAttributesJob - для расширенных атрибутов
    # - DownloadProductImagesJob - для загрузки картинок
    
    # Получаем количество (quantity) - ОБЯЗАТЕЛЬНОЕ ПОЛЕ
    # Стратегия 1: Из product_data (может быть из HTML парсинга)
    quantity_from_data = product_data['quantity'] || product_data[:quantity]
    if quantity_from_data.is_a?(Hash)
      quantity_from_data = quantity_from_data['quantity'] || quantity_from_data[:quantity]
    end
    
    # Стратегия 2: Из поля availability в API ответе (если есть)
    quantity_from_api = extract_quantity_from_api_response(product_data) unless quantity_from_data.present?
    
    # Стратегия 3: Из батч-запроса наличия
    quantity_from_availability = nil
    if item_no.present? && availability_data.present? && !quantity_from_data.present? && !quantity_from_api.present?
      availability = availability_data[item_no.to_s] || availability_data[item_no.to_i] || availability_data[item_no]
      if availability && availability[:quantity].present?
        quantity_from_availability = availability[:quantity] || availability['quantity'] || 0
      end
    end
    
    # Используем первое доступное значение
    attributes[:quantity] = quantity_from_data || quantity_from_api || quantity_from_availability || 0
    
    # Логируем предупреждение, если количество не найдено
    if attributes[:quantity] == 0
      Rails.logger.warn "ParseProductsJob: Product #{sku} (item_no: #{item_no}) has no quantity data from any source"
    else
      source = quantity_from_data ? 'HTML' : (quantity_from_api ? 'API' : 'availability')
      Rails.logger.debug "ParseProductsJob: Product #{sku} quantity: #{attributes[:quantity]} (source: #{source})"
    end
    
    # Обновляем is_parcel из данных наличия, если доступно
    if item_no.present? && availability_data.present?
      availability = availability_data[item_no.to_s] || availability_data[item_no.to_i] || availability_data[item_no]
      if availability && (availability[:is_parcel].present? || availability['is_parcel'].present?)
        attributes[:is_parcel] = availability[:is_parcel] || availability['is_parcel']
      end
    end
    
    # ВАЖНО: Переводим название продукта сразу в базовом парсере
    # Переводим только если name_ru еще не установлен или совпадает с оригиналом
    if name.present? && (product.nil? || product.name_ru.blank? || product.name_ru == product.name)
      begin
        attributes[:name_ru] = TranslationService.translate(
          name,
          target_lang: 'ru',
          source_lang: 'pl'
        )
        Rails.logger.debug "ParseProductsJob: Translated name for #{sku}: #{name} → #{attributes[:name_ru]}"
      rescue => e
        Rails.logger.warn "ParseProductsJob: Translation failed for product #{sku}: #{e.message}"
        # Продолжаем без перевода, не блокируем парсинг
      end
    elsif product && product.name_ru.present? && product.name_ru != product.name
      # Используем существующий перевод, если он есть
      attributes[:name_ru] = product.name_ru
    end
    
    # ВАЖНО: Создаем или обновляем продукт
    if product
      product.update!(attributes)
      result = { created: false, updated: true }
    else
      product = Product.create!(attributes)
      result = { created: true, updated: false }
    end
    
    # ВАЖНО: Создаем связь через CategoryProduct СРАЗУ после сохранения продукта
    # Это гарантирует, что продукт связан с категорией в процессе сбора данных
    category_product = CategoryProduct.find_or_create_by(
      product: product,
      category_id: category.ikea_id
    )
    
    if category_product.persisted? && category_product.previously_new_record?
      Rails.logger.info "ParseProductsJob: Created category_product link: #{product.sku} -> #{category.ikea_id}"
    else
      Rails.logger.debug "ParseProductsJob: Category_product link already exists: #{product.sku} -> #{category.ikea_id}"
    end
    
    # Примечание: Загрузка изображений вынесена в отдельную задачу DownloadProductImagesJob
    # Здесь только сохраняем URL изображений в поле images
    
    result
  end
  
  # Извлечение количества из API ответа (поле availability)
  def extract_quantity_from_api_response(product_data)
    return nil unless product_data.is_a?(Hash)
    
    # Пробуем извлечь из поля availability
    availability = product_data['availability'] || product_data[:availability]
    return nil unless availability.present?
    
    # availability может быть массивом объектов
    if availability.is_a?(Array)
      # Ищем объект с типом HOME_DELIVERY или CASH_AND_CARRY
      home_delivery = availability.find { |a| 
        (a['type2'] == 'HOME_DELIVERY' || a[:type2] == 'HOME_DELIVERY') ||
        (a['type'] == 'HOME_DELIVERY' || a[:type] == 'HOME_DELIVERY')
      }
      cash_carry = availability.find { |a| 
        (a['type2'] == 'CASH_AND_CARRY' || a[:type2] == 'CASH_AND_CARRY') ||
        (a['type'] == 'CASH_AND_CARRY' || a[:type] == 'CASH_AND_CARRY')
      }
      
      # Пробуем извлечь quantity из объекта
      avail_obj = home_delivery || cash_carry
      if avail_obj
        # Пробуем разные пути к quantity
        quantity = avail_obj['quantity'] || avail_obj[:quantity] || 
                   avail_obj.dig('availability', 'quantity') ||
                   avail_obj.dig(:availability, :quantity) ||
                   avail_obj.dig('stock', 'quantity') ||
                   avail_obj.dig(:stock, :quantity)
        
        # ВАЖНО: Если quantity не найдено, но есть status, преобразуем статус в количество
        if quantity.nil? && (avail_obj['status'] || avail_obj[:status])
          status = (avail_obj['status'] || avail_obj[:status]).to_s.upcase
          # Преобразуем статус в количество на основе реальных данных IKEA
          case status
          when 'HIGH_IN_STOCK', 'IN_STOCK'
            quantity = 999 # Высокий запас - много товара
          when 'LOW_IN_STOCK', 'LIMITED_STOCK'
            quantity = 5 # Низкий запас - мало товара
          when 'OUT_OF_STOCK', 'NOT_AVAILABLE', 'UNAVAILABLE'
            quantity = 0 # Нет в наличии
          when 'ONLINE_ONLY'
            quantity = 1 # Только онлайн
          else
            # Если статус неизвестен, но есть текст о наличии
            text = (avail_obj['text'] || avail_obj[:text] || '').to_s.downcase
            if text.include?('dostępn') || text.include?('available') || text.include?('in stock')
              quantity = 999
            elsif text.include?('brak') || text.include?('out of stock') || text.include?('unavailable')
              quantity = 0
            else
              quantity = 1 # По умолчанию - есть в наличии
            end
          end
        end
        
        return quantity.to_i if quantity.present?
      end
      
      # Если не нашли в HOME_DELIVERY/CASH_AND_CARRY, пробуем первый элемент массива
      if availability.any?
        first_avail = availability.first
        if first_avail.is_a?(Hash)
          status = (first_avail['status'] || first_avail[:status]).to_s.upcase
          case status
          when 'HIGH_IN_STOCK', 'IN_STOCK'
            return 999
          when 'LOW_IN_STOCK', 'LIMITED_STOCK'
            return 5
          when 'OUT_OF_STOCK', 'NOT_AVAILABLE', 'UNAVAILABLE'
            return 0
          end
        end
      end
    elsif availability.is_a?(Hash)
      # Если availability - это объект
      quantity = availability['quantity'] || availability[:quantity] ||
                 availability.dig('availability', 'quantity') ||
                 availability.dig(:availability, :quantity) ||
                 availability.dig('stock', 'quantity') ||
                 availability.dig(:stock, :quantity)
      
      # Если quantity не найдено, пробуем по статусу
      if quantity.nil? && (availability['status'] || availability[:status])
        status = (availability['status'] || availability[:status]).to_s.upcase
        case status
        when 'HIGH_IN_STOCK', 'IN_STOCK'
          quantity = 999
        when 'LOW_IN_STOCK', 'LIMITED_STOCK'
          quantity = 5
        when 'OUT_OF_STOCK', 'NOT_AVAILABLE', 'UNAVAILABLE'
          quantity = 0
        else
          quantity = 1
        end
      end
      
      return quantity.to_i if quantity.present?
    end
    
    nil
  end
end

