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
    
    Rails.logger.info "ParseProductsJob: Starting to fetch products for category #{category.ikea_id} (offset: #{offset})"
    
    loop do
      break if limit && stats[:processed] >= limit
      
      begin
        # Пробуем получить продукты через API поиска (только для числовых ID)
        products_data = []
        
        # Если category_id не UUID, пробуем API поиска
        unless category.ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) || category.ikea_id.to_s.include?('/')
          products_data = IkeaApiService.search_products_by_category(
            category.ikea_id,
            offset: offset,
            limit: page_size
          )
        end
        
        # Если API не вернул продукты (UUID категория или пустой результат), пробуем парсить HTML
        if products_data.empty? && category.url.present?
          Rails.logger.info "ParseProductsJob: API returned no products, trying to parse HTML page for category #{category.name}"
          products_data = CategoryProductsFetcher.fetch(
            category.url,
            offset: offset,
            limit: page_size
          )
        end
        
        Rails.logger.info "ParseProductsJob: Fetched #{products_data.length} products for category #{category.name} (ID: #{category.ikea_id})"
        
        break if products_data.empty?
        
        products_data.each do |product_data|
          break if limit && stats[:processed] >= limit
          
          # Проверяем статус задачи в каждой итерации
          check_task_not_stopped!(task)
          
          begin
            result = process_product(product_data, category)
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
        Rails.logger.error "Error fetching products for category #{category.ikea_id}: #{e.message}"
        stats[:errors] += 1
        task.increment_errors!
        break
      end
    end
  end

  def process_product(product_data, category)
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
      Rails.logger.info "ParseProductsJob: Product #{sku} - is_bestseller: #{is_bestseller}, is_popular: #{is_popular}"
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
    
    Rails.logger.info "ParseProductsJob: Base attributes for #{sku}: price=#{price}, images_count=#{images.length}"
    
    # Примечание: Расширенные атрибуты и загрузка картинок вынесены в отдельные задачи:
    # - FetchProductExtendedAttributesJob - для расширенных атрибутов
    # - DownloadProductImagesJob - для загрузки картинок
    
    # Получаем количество (quantity) через API наличия (приоритет над HTML)
    if item_no.present?
      begin
        Rails.logger.info "ParseProductsJob: Fetching availability for #{sku} (item_no: #{item_no})"
        availability_data = IkeaApiService.check_availability([item_no])
        Rails.logger.info "ParseProductsJob: Availability data for #{item_no}: #{availability_data.inspect}"
        
        # Пробуем найти данные по item_no (может быть строка или число)
        availability = availability_data[item_no.to_s] || availability_data[item_no.to_i] || availability_data[item_no]
        
        if availability && availability[:quantity].present?
          attributes[:quantity] = availability[:quantity] || availability['quantity'] || 0
          Rails.logger.info "ParseProductsJob: Set quantity from API to #{attributes[:quantity]} for #{sku} (item_no: #{item_no})"
          # Обновляем is_parcel из данных наличия, если доступно
          if availability[:is_parcel].present? || availability['is_parcel'].present?
            attributes[:is_parcel] = availability[:is_parcel] || availability['is_parcel']
          end
        else
          Rails.logger.warn "ParseProductsJob: No availability data from API for item_no #{item_no} (available keys: #{availability_data.keys.inspect})"
          # Если API не вернул данные, используем значение из HTML (если было установлено выше)
          attributes[:quantity] ||= 0
        end
      rescue => e
        Rails.logger.error("ParseProductsJob: Failed to fetch availability for #{item_no}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        # Если API ошибся, используем значение из HTML (если было установлено выше)
        attributes[:quantity] ||= 0
      end
    else
      Rails.logger.warn "ParseProductsJob: No item_no for #{sku}, skipping availability check"
      attributes[:quantity] ||= 0
    end
    
    # Примечание: Переводы вынесены в FetchProductExtendedAttributesJob
    # Здесь только базовый перевод названия для быстрого отображения
    if item_no.present? && attributes[:name_ru].blank? && attributes[:name].present?
      begin
        lt_details = LtDetailsFetcher.fetch(item_no)
        if lt_details.present? && lt_details[:translated] && lt_details[:name].present?
          attributes[:name_ru] = lt_details[:name]
          attributes[:translated] = true
        else
          # Fallback на автоматический перевод
          attributes[:name_ru] = TranslationService.translate(
            attributes[:name],
            target_lang: 'ru',
            source_lang: 'pl'
          )
          attributes[:translated] = false
        end
      rescue => e
        Rails.logger.warn("ParseProductsJob: Translation failed for product #{sku}: #{e.message}")
        attributes[:translated] = false
      end
    end
    
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

