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
    
    is_uuid_category = category.ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) || category.ikea_id.to_s.include?('/')
    proxy_list = ENV.fetch('PROXY_LIST', '').split(',').map(&:strip).reject(&:empty?)
    
    # Проверяем возможность обработки UUID категорий
    if is_uuid_category && proxy_list.empty?
      Rails.logger.warn "ParseProductsJob: Skipping UUID category #{category.ikea_id} (#{category.name}) - requires proxy for HTML parsing, but PROXY_LIST is empty"
      return # Пропускаем категорию без ошибки
    end
    
    loop do
      break if limit && stats[:processed] >= limit
      
      begin
        products_data = []
        
        # Для категорий с цифровым кодом используем расширенный поиск
        if !is_uuid_category
          # Используем новый сервис с несколькими стратегиями поиска
          products_data = CategoryProductsSearchService.search(
            category,
            offset: offset,
            limit: page_size,
            strategies: [
              :api_by_category_id,      # Сначала пробуем стандартный API
              :api_alternative_endpoint, # Затем альтернативный endpoint
              :api_by_category_name,     # Затем поиск по названию
              :html_parsing              # И наконец HTML парсинг
            ]
          )
          
          # Если не нашли продукты, пробуем retry
          if products_data.empty? && retry_count < max_retries
            retry_count += 1
            Rails.logger.info "ParseProductsJob: Retry #{retry_count}/#{max_retries} for category #{category.name} with extended search"
            sleep(2)
            redo
          end
        else
          # Для UUID категорий используем только HTML парсинг
          if category.url.present?
            begin
              Rails.logger.info "ParseProductsJob: Trying to parse HTML page for UUID category #{category.name} (URL: #{category.url})"
              products_data = CategoryProductsFetcher.fetch(
                category.url,
                offset: offset,
                limit: page_size
              )
              
              if products_data.empty? && retry_count < max_retries
                retry_count += 1
                Rails.logger.info "ParseProductsJob: Retry #{retry_count}/#{max_retries} for UUID category #{category.name}"
                sleep(2)
                redo
              end
            rescue => e
              Rails.logger.error "ParseProductsJob: HTML parsing failed for UUID category #{category.ikea_id}: #{e.message}"
              if retry_count < max_retries
                retry_count += 1
                Rails.logger.info "ParseProductsJob: Retry #{retry_count}/#{max_retries} for UUID category #{category.name}"
                sleep(2)
                redo
              end
            end
          end
        end
        
        Rails.logger.info "ParseProductsJob: Fetched #{products_data.length} products for category #{category.name} (ID: #{category.ikea_id}, offset: #{offset})"
        
        # Если не нашли продукты после всех попыток, логируем и выходим
        if products_data.empty?
          if offset == 0
            Rails.logger.warn "ParseProductsJob: No products found for category #{category.name} (ID: #{category.ikea_id}) after all attempts"
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
    
    # Цена может быть в разных форматах
    price = product_data.dig('salesPrice', 'numeral') || 
            product_data.dig(:salesPrice, :numeral) ||
            product_data.dig('salesPrice', :numeral) ||
            product_data.dig(:salesPrice, 'numeral') ||
            product_data.dig('price', 'numeral') || 
            product_data.dig(:price, :numeral) ||
            product_data['price'] || 
            product_data[:price]
    
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
    
    # Получаем количество (quantity) из батч-запроса наличия
    if item_no.present? && availability_data.present?
      # Пробуем найти данные по item_no (может быть строка или число)
      availability = availability_data[item_no.to_s] || availability_data[item_no.to_i] || availability_data[item_no]
      
      if availability && availability[:quantity].present?
        attributes[:quantity] = availability[:quantity] || availability['quantity'] || 0
        # Обновляем is_parcel из данных наличия, если доступно
        if availability[:is_parcel].present? || availability['is_parcel'].present?
          attributes[:is_parcel] = availability[:is_parcel] || availability['is_parcel']
        end
      else
        attributes[:quantity] ||= 0
      end
    else
      attributes[:quantity] ||= 0
    end
    
    # Примечание: Переводы вынесены в FetchProductExtendedAttributesJob
    # Здесь НЕ делаем перевод, чтобы не замедлять базовый парсинг
    # Перевод будет выполнен в FetchProductExtendedAttributesJob
    
    if product
      product.update!(attributes)
      result = { created: false, updated: true }
    else
      product = Product.create!(attributes)
      result = { created: true, updated: false }
    end
    
    # Примечание: Загрузка изображений вынесена в отдельную задачу DownloadProductImagesJob
    # Здесь только сохраняем URL изображений в поле images
    
    result
  end
end

