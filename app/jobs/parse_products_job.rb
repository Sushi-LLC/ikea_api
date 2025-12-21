# Задача для парсинга продуктов
class ParseProductsJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, category_id: nil)
    task = create_parser_task('products', limit: limit)
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
      
      categories.find_each do |category|
        break if limit && stats[:processed] >= limit
        
        process_category_products(category, task, stats, limit)
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('products', stats)
      
      # Автоматически запускаем загрузку картинок после завершения парсинга
      if stats[:processed] > 0
        Rails.logger.info "Starting image download jobs after products parsing..."
        
        # Загружаем картинки категорий (для всех категорий, у которых есть remote_image_url)
        DownloadCategoryImagesJob.perform_later(limit: nil)
        
        # Загружаем картинки продуктов (для всех продуктов, у которых есть images)
        DownloadProductImagesJob.perform_later(limit: nil)
      end
      
    rescue => e
      Rails.logger.error "ParseProductsJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('products', e)
      # Не пробрасываем ошибку дальше, чтобы задача была помечена как failed
    end
  end

  private

  def process_category_products(category, task, stats, limit)
    offset = 0
    page_size = 50
    
    loop do
      break if limit && stats[:processed] >= limit
      
      begin
        products_data = IkeaApiService.search_products_by_category(
          category.ikea_id,
          offset: offset,
          limit: page_size
        )
        
        break if products_data.empty?
        
        products_data.each do |product_data|
          break if limit && stats[:processed] >= limit
          
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
    sku = product_data['id']
    product = Product.find_by(sku: sku)
    
    pip_url = product_data['pipUrl'] || ''
    url = pip_url.start_with?('http') ? pip_url : "https://www.ikea.com#{pip_url}"
    item_no = product_data['itemNoGlobal'] || product_data['itemNo']
    name = product_data['typeName']
    
    # Базовые атрибуты
    attributes = {
      sku: sku,
      name: name,
      item_no: item_no,
      url: url,
      price: product_data.dig('salesPrice', 'numeral'),
      home_delivery: product_data['homeDelivery'],
      category_id: category.ikea_id,
      images: product_data.dig('gprDescription', 'variants')&.map { |v| v['imageUrl'] }&.compact || [],
      variants: product_data.dig('gprDescription', 'variants') || []
    }
    
    # Получаем расширенные параметры через PlDetailsFetcher
    begin
      pl_details = PlDetailsFetcher.fetch(url)
      
      if pl_details.present?
        # Вес и размеры
        attributes[:weight] = pl_details[:weight] if pl_details[:weight]
        attributes[:net_weight] = pl_details[:net_weight] if pl_details[:net_weight]
        attributes[:package_volume] = pl_details[:package_volume] if pl_details[:package_volume]
        attributes[:package_dimensions] = pl_details[:package_dimensions] if pl_details[:package_dimensions]
        attributes[:dimensions] = pl_details[:dimensions] if pl_details[:dimensions]
        
        # Коллекция
        attributes[:collection] = pl_details[:collection] if pl_details[:collection]
        
        # Set items, bundle items, related products
        attributes[:set_items] = pl_details[:set_items] if pl_details[:set_items]
        attributes[:bundle_items] = pl_details[:bundle_items] if pl_details[:bundle_items]
        attributes[:related_products] = pl_details[:related_products] if pl_details[:related_products]
        
        # Видео и инструкции
        attributes[:videos] = pl_details[:videos] if pl_details[:videos]
        attributes[:manuals] = pl_details[:manuals] if pl_details[:manuals]
        
        # Определяем is_parcel (вес <= 30 кг)
        if attributes[:weight]
          attributes[:is_parcel] = attributes[:weight] <= 30.0
        end
      end
    rescue => e
      Rails.logger.warn("Failed to fetch PL details for #{sku}: #{e.message}")
    end
    
    # Получаем переводы через LtDetailsFetcher
    if item_no.present?
      begin
        lt_details = LtDetailsFetcher.fetch(item_no)
        
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
          
          # Материалы и описание
          attributes[:material_info] = lt_details[:material_text] if lt_details[:material_text].present?
          attributes[:material_info_ru] = lt_details[:material_text] if lt_details[:material_text].present?
          attributes[:good_info] = lt_details[:good_text] if lt_details[:good_text].present?
          attributes[:good_info_ru] = lt_details[:good_text] if lt_details[:good_text].present?
          attributes[:content] = lt_details[:details_text] if lt_details[:details_text].present?
          attributes[:content_ru] = lt_details[:details_text] if lt_details[:details_text].present?
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
    
    if product
      product.update!(attributes)
      { created: false, updated: true }
    else
      Product.create!(attributes)
      { created: true, updated: false }
    end
  end
end

