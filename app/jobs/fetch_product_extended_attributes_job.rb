# Задача для загрузки расширенных атрибутов продуктов
class FetchProductExtendedAttributesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, product_id: nil, task_id: nil)
    # Если task_id передан, используем существующую задачу, иначе создаем новую
    task = task_id ? ParserTask.find(task_id) : create_parser_task('extended_attributes', limit: limit)
    
    # Проверяем, не остановлена ли задача перед началом выполнения
    check_task_not_stopped!(task)
    
    task.mark_as_running!
    
    notify_started('extended_attributes', limit: limit)
    start_time = Time.current
    
    stats = {
      processed: 0,
      updated: 0,
      errors: 0
    }
    
    begin
      products = if product_id
                   Product.where(sku: product_id)
                 else
                   # Ищем продукты с URL, но без расширенных атрибутов
                   Product.where.not(url: nil)
                          .where("url != ''")
                          .limit(limit || 1000)
                 end
      
      products.find_each do |product|
        break if limit && stats[:processed] >= limit
        
        # Проверяем, не остановлена ли задача
        check_task_not_stopped!(task)
        
        begin
          result = fetch_extended_attributes(product)
          stats[:updated] += 1 if result[:updated]
          stats[:processed] += 1
          task.increment_processed!
          task.increment_updated! if result[:updated]
        rescue => e
          Rails.logger.error "Error fetching extended attributes for product #{product.sku}: #{e.message}"
          stats[:errors] += 1
          task.increment_errors!
        end
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('extended_attributes', stats)
      
    rescue StandardError => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "FetchProductExtendedAttributesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "FetchProductExtendedAttributesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('extended_attributes', e)
      raise
    rescue => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "FetchProductExtendedAttributesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "FetchProductExtendedAttributesJob unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!("Unexpected error: #{e.message}")
      notify_error('extended_attributes', e)
    end
  end

  private

  def fetch_extended_attributes(product)
    return { updated: false } unless product.url.present?
    
    Rails.logger.info "FetchProductExtendedAttributesJob: Fetching extended attributes for #{product.sku} from #{product.url}"

    Rails.logger.info "FetchProductExtendedAttributesJob: Trying PL fetch without headless for #{product.sku}"
    headless_allowed = pl_headless_enabled?
    pl_details = PlDetailsFetcher.fetch(product.url, use_headless: false) || {}

    if !pl_modal_fields_complete?(pl_details)
      if headless_allowed
        Rails.logger.info "FetchProductExtendedAttributesJob: PL fetch without headless incomplete -> trying headless"
        headless_details = PlDetailsFetcher.fetch(product.url, use_headless: true)
        pl_details = headless_details if headless_details.present?
      else
        Rails.logger.info "FetchProductExtendedAttributesJob: Headless disabled by PL_FETCHER_ENABLE_HEADLESS"
      end
    end

    Rails.logger.info "FetchProductExtendedAttributesJob: PL details final: #{pl_details.present? ? 'present' : 'empty'} (materials: #{pl_details[:materials].present?}, care_instructions: #{pl_details[:care_instructions].present?}, safety_info: #{pl_details[:safety_info].present?})"

    return { updated: false } unless pl_details.present?
    
    attributes = {}
    
    # Объединяем изображения с уже имеющимися (если есть новые)
    if pl_details[:images].present? && pl_details[:images].is_a?(Array) && pl_details[:images].any?
      existing_images = if product.images.is_a?(Array)
                        product.images
                      elsif product.images.is_a?(String)
                        begin
                          JSON.parse(product.images) || []
                        rescue
                          []
                        end
                      else
                        []
                      end
      
      all_images = (existing_images + pl_details[:images]).compact.uniq
      attributes[:images] = all_images if all_images.length > existing_images.length
      Rails.logger.info "FetchProductExtendedAttributesJob: Merged images for #{product.sku}: total=#{all_images.length} (existing: #{existing_images.length}, new: #{pl_details[:images].length})"
    end
    
    # Вес и размеры
    attributes[:weight] = pl_details[:weight] if pl_details[:weight]
    attributes[:net_weight] = pl_details[:net_weight] if pl_details[:net_weight]
    attributes[:package_volume] = pl_details[:package_volume] if pl_details[:package_volume]
    attributes[:package_dimensions] = pl_details[:package_dimensions] if pl_details[:package_dimensions]
    attributes[:dimensions] = pl_details[:dimensions] if pl_details[:dimensions]
    
    # Коллекция
    attributes[:collection] = pl_details[:collection] if pl_details[:collection]
    
    # Описание продукта
    if pl_details[:description].present?
      attributes[:content] = pl_details[:description]
    end
    if pl_details[:short_description].present?
      attributes[:short_description] = pl_details[:short_description]
    end
    
    # Расширенные атрибуты
    if pl_details[:materials].present?
      attributes[:materials] = pl_details[:materials].is_a?(Array) ? pl_details[:materials].join("\n") : pl_details[:materials]
    end
    if pl_details[:features].present?
      attributes[:features] = pl_details[:features]
    end
    if pl_details[:care_instructions].present?
      attributes[:care_instructions] = pl_details[:care_instructions]
    end
    if pl_details[:environmental_info].present?
      attributes[:environmental_info] = pl_details[:environmental_info]
    end
    
    # Связанные продукты
    attributes[:set_items] = pl_details[:set_items] if pl_details[:set_items]
    attributes[:bundle_items] = pl_details[:bundle_items] if pl_details[:bundle_items]
    if pl_details[:related_products].present?
      attributes[:related_products] = pl_details[:related_products]
      Rails.logger.info "FetchProductExtendedAttributesJob: Found #{pl_details[:related_products].length} related products for #{product.sku}"
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
      Rails.logger.info "FetchProductExtendedAttributesJob: Found #{pl_details[:assembly_documents].length} assembly documents for #{product.sku}"
    end
    
    # Если цена не была установлена ранее, пробуем получить из pl_details
    if product.price.blank? && pl_details[:price]
      attributes[:price] = pl_details[:price]
    end
    
    # Определяем is_parcel (вес <= 30 кг)
    if attributes[:weight] && product.is_parcel.nil?
      attributes[:is_parcel] = attributes[:weight] <= 30.0
    end
    
    # Используем наличие из HTML, если доступно
    if pl_details[:availability].present?
      html_availability = pl_details[:availability]
      if html_availability[:quantity].present? && (product.quantity.blank? || product.quantity == 0)
        attributes[:quantity] = html_availability[:quantity]
        Rails.logger.info "FetchProductExtendedAttributesJob: Set quantity from HTML to #{attributes[:quantity]} for #{product.sku}"
      end
    end
    
    # Получаем количество (quantity) через API наличия (приоритет над HTML)
    if product.item_no.present?
      begin
        Rails.logger.info "FetchProductExtendedAttributesJob: Fetching availability for #{product.sku} (item_no: #{product.item_no})"
        availability_data = IkeaApiService.check_availability([product.item_no])
        
        availability = availability_data[product.item_no.to_s] || availability_data[product.item_no.to_i] || availability_data[product.item_no]
        
        if availability && availability[:quantity].present?
          attributes[:quantity] = availability[:quantity] || availability['quantity'] || 0
          Rails.logger.info "FetchProductExtendedAttributesJob: Set quantity from API to #{attributes[:quantity]} for #{product.sku}"
          if availability[:is_parcel].present? || availability['is_parcel'].present?
            attributes[:is_parcel] = availability[:is_parcel] || availability['is_parcel']
          end
        end
      rescue => e
        Rails.logger.error("FetchProductExtendedAttributesJob: Failed to fetch availability for #{product.item_no}: #{e.message}")
      end
    end
    
    # Получаем переводы через LtDetailsFetcher
    if product.item_no.present?
      begin
        Rails.logger.info "FetchProductExtendedAttributesJob: Fetching LT details for #{product.sku} (item_no: #{product.item_no})"
        lt_details = LtDetailsFetcher.fetch(product.item_no)
        Rails.logger.info "FetchProductExtendedAttributesJob: LT details fetched for #{product.item_no}: #{lt_details.present? ? 'present' : 'empty'}, translated: #{lt_details[:translated]}"
        
        if lt_details.present? && lt_details[:translated]
          # Переводим название продукта
          if lt_details[:name].present?
            attributes[:name_ru] = lt_details[:name]
          end
          
          # Материалы из LT (приоритет над PL)
          if lt_details[:materials].present? || lt_details[:material_text].present?
            attributes[:materials] = lt_details[:materials] || lt_details[:material_text]
            attributes[:materials_ru] = lt_details[:materials] || lt_details[:material_text]
            Rails.logger.info "FetchProductExtendedAttributesJob: Set materials from LT for #{product.sku}"
          end
          
          # "Полезно знать" из LT (приоритет над PL)
          if lt_details[:good_to_know].present? || lt_details[:good_text].present?
            attributes[:good_to_know] = lt_details[:good_to_know] || lt_details[:good_text]
            attributes[:good_to_know_ru] = lt_details[:good_to_know] || lt_details[:good_text]
            Rails.logger.info "FetchProductExtendedAttributesJob: Set good_to_know from LT for #{product.sku}"
          end
          
          # Описание продукта (content) из LT - приоритет над PL
          if lt_details[:content].present? || lt_details[:details_text].present?
            if attributes[:content].blank?
              attributes[:content] = lt_details[:content] || lt_details[:details_text]
              attributes[:content_ru] = lt_details[:content] || lt_details[:details_text]
              Rails.logger.info "FetchProductExtendedAttributesJob: Set content from LT for #{product.sku}"
            end
          end
          
          # Старые поля для совместимости
          attributes[:material_info] = lt_details[:material_text] if lt_details[:material_text].present?
          attributes[:material_info_ru] = lt_details[:material_text] if lt_details[:material_text].present?
          attributes[:good_info] = lt_details[:good_text] if lt_details[:good_text].present?
          attributes[:good_info_ru] = lt_details[:good_text] if lt_details[:good_text].present?
          
          attributes[:translated] = true
        end
      rescue => e
        Rails.logger.warn("FetchProductExtendedAttributesJob: Failed to fetch LT details for #{product.item_no}: #{e.message}")
      end
    end
    
    # Переводим все текстовые атрибуты на русский язык (если еще не переведены)
    begin
      Rails.logger.info "FetchProductExtendedAttributesJob: Translating text attributes for #{product.sku}"
      
      # Переводим название (если еще не переведено из LT)
      if attributes[:name_ru].blank? && (product.name_ru.blank? || product.name_ru == product.name)
        name_to_translate = attributes[:name] || product.name
        if name_to_translate.present?
          attributes[:name_ru] = TranslationService.translate(
            name_to_translate,
            target_lang: 'ru',
            source_lang: 'pl'
          )
        end
      end
      
      # Переводим краткое описание
      if attributes[:short_description].present? && attributes[:short_description_ru].blank?
        attributes[:short_description_ru] = TranslationService.translate(
          attributes[:short_description],
          target_lang: 'ru',
          source_lang: 'pl'
        )
      end
      
      # Переводим описание (content)
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
      
      # Переводим дизайнера
      if attributes[:designer].present? && attributes[:designer_ru].blank?
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
      
      Rails.logger.info "FetchProductExtendedAttributesJob: Translation completed for #{product.sku}"
    rescue => e
      Rails.logger.error("FetchProductExtendedAttributesJob: Translation failed for #{product.sku}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    end
    
    # Обновляем продукт только если есть изменения
    if attributes.any?
      product.update!(attributes)
      Rails.logger.info "FetchProductExtendedAttributesJob: Updated extended attributes for #{product.sku}"
      { updated: true }
    else
      Rails.logger.info "FetchProductExtendedAttributesJob: No extended attributes to update for #{product.sku}"
      { updated: false }
    end
  end

  def pl_modal_fields_complete?(details)
    details.present? &&
      details[:materials].present? &&
      details[:care_instructions].present? &&
      details[:safety_info].present?
  end

  def pl_headless_enabled?
    env_value = ENV.fetch('PL_FETCHER_ENABLE_HEADLESS', 'true').to_s.downcase
    %w[true 1 yes].include?(env_value)
  end
end

