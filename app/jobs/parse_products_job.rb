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
      
      # Картинки продуктов загружаются вместе с продуктами в process_product
      
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
    
    # Получаем расширенные параметры через PlDetailsFetcher (обязательные поля)
    begin
      Rails.logger.info "ParseProductsJob: Fetching PL details for #{sku} from #{url}"
      pl_details = PlDetailsFetcher.fetch(url)
      Rails.logger.info "ParseProductsJob: PL details fetched for #{sku}: #{pl_details.present? ? 'present' : 'empty'}"
      
      if pl_details.present?
        # Изображения: объединяем с уже имеющимися, приоритет у изображений со страницы продукта
        if pl_details[:images].present? && pl_details[:images].is_a?(Array) && pl_details[:images].any?
          # Объединяем изображения, убирая дубликаты
          existing_images = attributes[:images] || []
          all_images = existing_images + pl_details[:images]
          attributes[:images] = all_images.compact.uniq
          Rails.logger.info "ParseProductsJob: Merged images for #{sku}: total=#{attributes[:images].length} (from API: #{existing_images.length}, from page: #{pl_details[:images].length})"
        elsif pl_details[:images].present?
          Rails.logger.warn "ParseProductsJob: pl_details[:images] is present but not an array or empty: #{pl_details[:images].class} - #{pl_details[:images].inspect}"
        else
          Rails.logger.warn "ParseProductsJob: No images found in pl_details for #{sku}"
        end
        
        # Вес и размеры (обязательные поля)
        attributes[:weight] = pl_details[:weight] if pl_details[:weight]
        attributes[:net_weight] = pl_details[:net_weight] if pl_details[:net_weight]
        attributes[:package_volume] = pl_details[:package_volume] if pl_details[:package_volume]
        attributes[:package_dimensions] = pl_details[:package_dimensions] if pl_details[:package_dimensions]
        attributes[:dimensions] = pl_details[:dimensions] if pl_details[:dimensions]
        
        # Коллекция (обязательное поле)
        attributes[:collection] = pl_details[:collection] if pl_details[:collection]
        
        # Описание продукта из PL страницы (если не получено из LT)
        if pl_details[:description].present? && attributes[:content].blank?
          attributes[:content] = pl_details[:description]
        end
        if pl_details[:short_description].present?
          attributes[:short_description] = pl_details[:short_description]
        end
        
        # Расширенные атрибуты
        if pl_details[:materials].present?
          # Материалы могут быть строкой или массивом
          attributes[:materials] = pl_details[:materials].is_a?(Array) ? pl_details[:materials].join("\n") : pl_details[:materials]
        end
        if pl_details[:features].present?
          # Характеристики могут быть массивом или строкой
          attributes[:features] = pl_details[:features]
        end
        if pl_details[:care_instructions].present?
          attributes[:care_instructions] = pl_details[:care_instructions]
        end
        if pl_details[:environmental_info].present?
          attributes[:environmental_info] = pl_details[:environmental_info]
        end
        if pl_details[:short_description].present?
          attributes[:short_description] = pl_details[:short_description]
        end
        
        # Связанные продукты (обязательное поле)
        attributes[:set_items] = pl_details[:set_items] if pl_details[:set_items]
        attributes[:bundle_items] = pl_details[:bundle_items] if pl_details[:bundle_items]
        if pl_details[:related_products].present?
          attributes[:related_products] = pl_details[:related_products]
          Rails.logger.info "ParseProductsJob: Found #{pl_details[:related_products].length} related products for #{sku}: #{pl_details[:related_products].inspect}"
        else
          Rails.logger.warn "ParseProductsJob: No related products found for #{sku}"
        end
        
        # Видео и инструкции
        attributes[:videos] = pl_details[:videos] if pl_details[:videos]
        attributes[:manuals] = pl_details[:manuals] if pl_details[:manuals]
        
        # Данные из модального окна
        attributes[:designer] = pl_details[:designer] if pl_details[:designer]
        attributes[:safety_info] = pl_details[:safety_info] if pl_details[:safety_info]
        attributes[:good_to_know] = pl_details[:good_to_know] if pl_details[:good_to_know]
        if pl_details[:assembly_documents].present?
          attributes[:assembly_documents] = pl_details[:assembly_documents]
          Rails.logger.info "ParseProductsJob: Found #{pl_details[:assembly_documents].length} assembly documents for #{sku}"
        end
        
        # Если цена не была установлена ранее, пробуем получить из pl_details
        if attributes[:price].blank? && pl_details[:price]
          attributes[:price] = pl_details[:price]
        end
        
        # Определяем is_parcel (вес <= 30 кг), если не установлено из availability
        if attributes[:weight] && attributes[:is_parcel].nil?
          attributes[:is_parcel] = attributes[:weight] <= 30.0
        end
        
        # Используем наличие из HTML, если доступно
        if pl_details[:availability].present?
          html_availability = pl_details[:availability]
          if html_availability[:quantity].present? && (attributes[:quantity].blank? || attributes[:quantity] == 0)
            attributes[:quantity] = html_availability[:quantity]
            Rails.logger.info "ParseProductsJob: Set quantity from HTML to #{attributes[:quantity]} for #{sku}"
          end
        end
      end
    rescue => e
      Rails.logger.error("ParseProductsJob: Failed to fetch PL details for #{sku}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    end
    
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
    
    # Получаем переводы через LtDetailsFetcher
    if item_no.present?
      begin
        Rails.logger.info "ParseProductsJob: Fetching LT details for #{sku} (item_no: #{item_no})"
        lt_details = LtDetailsFetcher.fetch(item_no)
        Rails.logger.info "ParseProductsJob: LT details fetched for #{item_no}: #{lt_details.present? ? 'present' : 'empty'}, translated: #{lt_details[:translated]}"
        
        if lt_details.present? && lt_details[:translated]
          # Переводим название продукта
          if lt_details[:name].present?
            attributes[:name_ru] = lt_details[:name]
          else
            # Если нет перевода из LT, используем сервис перевода
            begin
              attributes[:name_ru] = TranslationService.translate(
                name,
                target_lang: 'ru',
                source_lang: 'pl'
              ) if name.present?
            rescue => e
              Rails.logger.warn("Translation failed for product #{sku}: #{e.message}")
            end
          end
          
          # Материалы из LT (приоритет над PL) - как в оригинальном парсере
          if lt_details[:materials].present? || lt_details[:material_text].present?
            attributes[:materials] = lt_details[:materials] || lt_details[:material_text]
            attributes[:materials_ru] = lt_details[:materials] || lt_details[:material_text]
            Rails.logger.info "ParseProductsJob: Set materials from LT for #{sku}"
          end
          
          # "Полезно знать" из LT (приоритет над PL)
          if lt_details[:good_to_know].present? || lt_details[:good_text].present?
            attributes[:good_to_know] = lt_details[:good_to_know] || lt_details[:good_text]
            attributes[:good_to_know_ru] = lt_details[:good_to_know] || lt_details[:good_text]
            Rails.logger.info "ParseProductsJob: Set good_to_know from LT for #{sku}"
          end
          
          # Описание продукта (content) из LT - приоритет над PL, если не было получено из PL
          if lt_details[:content].present? || lt_details[:details_text].present?
            if attributes[:content].blank?
              attributes[:content] = lt_details[:content] || lt_details[:details_text]
              attributes[:content_ru] = lt_details[:content] || lt_details[:details_text]
              Rails.logger.info "ParseProductsJob: Set content from LT for #{sku}"
            end
          end
          
          # Старые поля для совместимости
          attributes[:material_info] = lt_details[:material_text] if lt_details[:material_text].present?
          attributes[:material_info_ru] = lt_details[:material_text] if lt_details[:material_text].present?
          attributes[:good_info] = lt_details[:good_text] if lt_details[:good_text].present?
          attributes[:good_info_ru] = lt_details[:good_text] if lt_details[:good_text].present?
          
          attributes[:translated] = true
        else
          # Если перевод не получен, пробуем через сервис перевода
          begin
            attributes[:name_ru] = TranslationService.translate(
              name,
              target_lang: 'ru',
              source_lang: 'pl'
            ) if name.present?
            attributes[:translated] = false
          rescue => e
            Rails.logger.warn("Translation failed for product #{sku}: #{e.message}")
            attributes[:translated] = false
          end
        end
      rescue => e
        Rails.logger.warn("Failed to fetch LT details for #{item_no}: #{e.message}")
        # Пробуем перевести только название
        begin
          attributes[:name_ru] = TranslationService.translate(
            name,
            target_lang: 'ru',
            source_lang: 'pl'
          ) if name.present?
        rescue => e2
          Rails.logger.warn("Translation failed for product #{sku}: #{e2.message}")
        end
        attributes[:translated] = false
      end
    end
    
    # Переводим все текстовые атрибуты на русский язык (если еще не переведены)
    # Делаем это после получения всех данных, но перед сохранением
    begin
      Rails.logger.info "ParseProductsJob: Translating text attributes for #{sku}"
      
      # Переводим название (если еще не переведено из LT)
      if attributes[:name_ru].blank? && attributes[:name].present?
        attributes[:name_ru] = TranslationService.translate(
          attributes[:name],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим краткое описание
      if attributes[:short_description].present? && attributes[:short_description_ru].blank?
        attributes[:short_description_ru] = TranslationService.translate(
          attributes[:short_description],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим описание (content) - только если не получено из LT
      if attributes[:content].present? && attributes[:content_ru].blank?
        attributes[:content_ru] = TranslationService.translate(
          attributes[:content],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим материалы
      if attributes[:materials].present? && attributes[:materials_ru].blank?
        materials_text = attributes[:materials].is_a?(Array) ? attributes[:materials].join("\n") : attributes[:materials]
        attributes[:materials_ru] = TranslationService.translate(
          materials_text,
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим характеристики (features)
      if attributes[:features].present? && attributes[:features_ru].blank?
        features_text = attributes[:features].is_a?(Array) ? attributes[:features].join("\n") : attributes[:features]
        attributes[:features_ru] = TranslationService.translate(
          features_text,
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим инструкции по уходу
      if attributes[:care_instructions].present? && attributes[:care_instructions_ru].blank?
        attributes[:care_instructions_ru] = TranslationService.translate(
          attributes[:care_instructions],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим экологическую информацию
      if attributes[:environmental_info].present? && attributes[:environmental_info_ru].blank?
        attributes[:environmental_info_ru] = TranslationService.translate(
          attributes[:environmental_info],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим дизайнера (если это текст, а не просто имя)
      if attributes[:designer].present? && attributes[:designer_ru].blank?
        # Дизайнер обычно имя собственное, но переводим на всякий случай
        attributes[:designer_ru] = TranslationService.translate(
          attributes[:designer],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим информацию о безопасности
      if attributes[:safety_info].present? && attributes[:safety_info_ru].blank?
        attributes[:safety_info_ru] = TranslationService.translate(
          attributes[:safety_info],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим "Полезно знать"
      if attributes[:good_to_know].present? && attributes[:good_to_know_ru].blank?
        attributes[:good_to_know_ru] = TranslationService.translate(
          attributes[:good_to_know],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      Rails.logger.info "ParseProductsJob: Translation completed for #{sku}"
    rescue => e
      Rails.logger.error("ParseProductsJob: Translation failed for #{sku}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      # Продолжаем работу даже если перевод не удался
    end
    
    if product
      product.update!(attributes)
      result = { created: false, updated: true }
    else
      product = Product.create!(attributes)
      result = { created: true, updated: false }
    end
    
    # Загружаем изображения продукта сразу после сохранения
    images_to_download = attributes[:images] || []
    
    # Если images - это строка (JSON), парсим её
    if images_to_download.is_a?(String)
      begin
        images_to_download = JSON.parse(images_to_download)
      rescue JSON::ParserError
        Rails.logger.warn "ParseProductsJob: Failed to parse images JSON for #{product.sku}: #{images_to_download}"
        images_to_download = []
      end
    end
    
    Rails.logger.info "ParseProductsJob: Checking images for #{product.sku}: count=#{images_to_download.length}, type=#{images_to_download.class}, images=#{images_to_download[0..2].inspect}"
    
    if images_to_download.present? && images_to_download.is_a?(Array) && images_to_download.any?
      begin
        Rails.logger.info "ParseProductsJob: Downloading #{images_to_download.length} images for product #{product.sku}"
        downloaded = ImageDownloader.download_product_images(product, images_to_download, limit: nil)
        Rails.logger.info "ParseProductsJob: Downloaded #{downloaded.length} images for product #{product.sku} (requested: #{images_to_download.length})"
      rescue => e
        Rails.logger.error("ParseProductsJob: Failed to download images for product #{product.sku}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        # Не прерываем процесс парсинга из-за ошибки загрузки изображений
      end
    else
      Rails.logger.warn "ParseProductsJob: No images to download for product #{product.sku} (images: #{images_to_download.inspect}, type: #{images_to_download.class})"
    end
    
    result
  end
end

