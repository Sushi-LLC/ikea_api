# Задача для парсинга хитов продаж
# Обновляет флаг is_bestseller на основе данных из API IKEA
class ParseBestsellersJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, task_id: nil)
    # Если task_id передан, используем существующую задачу, иначе создаем новую
    task = task_id ? ParserTask.find(task_id) : create_parser_task('bestsellers', limit: limit)
    
    # Проверяем, не остановлена ли задача перед началом выполнения
    check_task_not_stopped!(task)
    
    task.mark_as_running!
    
    notify_started('bestsellers', limit: limit)
    start_time = Time.current
    
    stats = {
      processed: 0,
      created: 0,
      updated: 0,
      errors: 0
    }
    
    begin
      # Сначала пробуем получить с главной страницы через scrape.do
      Rails.logger.info "ParseBestsellersJob: Fetching bestsellers from homepage via scrape.do"
      homepage_data = HomepageFetcher.fetch
      bestseller_skus = homepage_data[:bestseller_skus] || []
      
      # Если не получилось с главной страницы, используем старый метод
      if bestseller_skus.empty?
        Rails.logger.info "ParseBestsellersJob: No bestsellers from homepage, trying BestsellersFetcher"
        bestseller_skus = BestsellersFetcher.fetch(limit: limit || 1000)
      else
        Rails.logger.info "ParseBestsellersJob: Found #{bestseller_skus.length} bestsellers from homepage"
      end
      
      if bestseller_skus.empty?
        Rails.logger.warn "ParseBestsellersJob: No bestsellers found via fetcher, trying category-based approach"
        # Fallback: проходим по категориям
        categories = Category.active.limit(limit || 100)
        categories.find_each do |category|
          break if limit && stats[:processed] >= limit
          check_task_not_stopped!(task)
          process_bestsellers_for_category(category, task, stats, limit)
        end
      else
        # Обновляем флаги is_bestseller для найденных продуктов
        process_bestseller_skus(bestseller_skus, task, stats, limit)
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('bestsellers', stats)
      
    rescue StandardError => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "ParseBestsellersJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "ParseBestsellersJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('bestsellers', e)
      raise
    rescue => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "ParseBestsellersJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "ParseBestsellersJob unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!("Unexpected error: #{e.message}")
      notify_error('bestsellers', e)
    end
  end

  private

  def process_bestseller_skus(skus, task, stats, limit)
    Rails.logger.info "ParseBestsellersJob: Processing #{skus.length} bestseller SKUs"
    Rails.logger.info "ParseBestsellersJob: First 10 SKUs: #{skus.first(10).inspect}"
    
    # Сначала сбрасываем все флаги is_bestseller
    Product.update_all(is_bestseller: false)
    Rails.logger.info "ParseBestsellersJob: Reset all is_bestseller flags to false"
    
    found_count = 0
    not_found_skus = []
    
      # Устанавливаем is_bestseller для найденных продуктов
      skus.each do |sku|
        break if limit && stats[:processed] >= limit
        
        check_task_not_stopped!(task)
        
        # Нормализуем SKU (может быть с точками, дефисами, буквами)
        normalized_sku = sku.to_s.strip.gsub(/[.\-\s]/, '')
        original_sku = sku.to_s.strip
        
        # Пробуем найти продукт по разным вариантам SKU
        # 1. Точное совпадение
        product = Product.find_by(sku: normalized_sku) || 
                  Product.find_by(sku: original_sku)
        
        # 2. Если не найдено, пробуем варианты (с/без буквы s в начале)
        unless product
          # Убираем букву s в начале, если есть
          sku_without_s = normalized_sku.gsub(/^s/i, '')
          product = Product.find_by(sku: sku_without_s) if sku_without_s != normalized_sku
          
          # Добавляем букву s в начало
          sku_with_s = "s#{sku_without_s}"
          product = Product.find_by(sku: sku_with_s) if sku_with_s != normalized_sku && !product
        end
        
        # 3. Частичное совпадение (последние 8 цифр)
        unless product
          digits_only = normalized_sku.gsub(/[^0-9]/, '')
          if digits_only.length >= 6
            product = Product.where("sku LIKE ?", "%#{digits_only[-8..-1]}%").first if digits_only.length >= 8
            product ||= Product.where("sku LIKE ?", "%#{digits_only}%").first
          end
        end
        
        # 4. Поиск по URL (если SKU в URL)
        unless product
          product = Product.where("url LIKE ?", "%#{normalized_sku}%").first ||
                    Product.where("url LIKE ?", "%#{original_sku}%").first
        end
      
      if product
        unless product.is_bestseller
          product.update!(is_bestseller: true)
          stats[:updated] += 1
          task.increment_updated!
          found_count += 1
          Rails.logger.info "ParseBestsellersJob: Marked product #{product.name} (SKU: #{product.sku}) as bestseller (found by: #{original_sku})"
        end
      else
        not_found_skus << original_sku
        Rails.logger.debug "ParseBestsellersJob: Product with SKU '#{original_sku}' (normalized: '#{normalized_sku}') not found in database"
      end
      
      stats[:processed] += 1
      task.increment_processed!
    end
    
    Rails.logger.info "ParseBestsellersJob: Found #{found_count} products, #{not_found_skus.length} not found"
    if not_found_skus.length > 0 && not_found_skus.length <= 20
      Rails.logger.warn "ParseBestsellersJob: Not found SKUs (first 20): #{not_found_skus.first(20).inspect}"
    end
  end

  def process_bestsellers_for_category(category, task, stats, limit)
    Rails.logger.info "ParseBestsellersJob: Processing category #{category.name} (ID: #{category.ikea_id})"
    
    begin
      # Пробуем получить продукты через API
      products_data = IkeaApiService.search_products_by_category(
        category.ikea_id,
        offset: 0,
        limit: 50
      )
      
      # Если API не вернул продукты (UUID категория), пробуем парсить HTML
      if products_data.empty? && category.url.present?
        Rails.logger.info "ParseBestsellersJob: API returned no products, trying to parse HTML page for category #{category.name}"
        products_data = CategoryProductsFetcher.fetch(
          category.url,
          offset: 0,
          limit: 50
        ).map(&:with_indifferent_access)
      end
      
      Rails.logger.info "ParseBestsellersJob: Fetched #{products_data.length} products for category #{category.name}"
      
      products_data.each do |product_data|
        break if limit && stats[:processed] >= limit
        
        # Проверяем статус задачи в каждой итерации
        check_task_not_stopped!(task)
        
        begin
          # Нормализуем данные
          product_data = product_data.with_indifferent_access if product_data.is_a?(Hash)
          
          sku = product_data['id'] || product_data[:id] || product_data['sku'] || product_data[:sku]
          next unless sku.present?
          
          product = Product.find_by(sku: sku)
          
          # Извлекаем флаг isBestseller из API ответа
          is_bestseller = product_data['isBestseller'] || 
                          product_data['is_bestseller'] || 
                          product_data[:isBestseller] || 
                          product_data[:is_bestseller] || 
                          product_data['bestseller'] || 
                          product_data[:bestseller] || 
                          false
          
          if product
            # Обновляем флаг только если значение изменилось
            was_bestseller = product.is_bestseller
            
            if was_bestseller != is_bestseller
              product.update!(is_bestseller: is_bestseller)
              stats[:updated] += 1
              task.increment_updated!
              Rails.logger.info "ParseBestsellersJob: Updated product #{product.sku} - is_bestseller: #{was_bestseller} -> #{is_bestseller}"
            end
          else
            Rails.logger.warn "ParseBestsellersJob: Product with SKU #{sku} not found in database. Run ParseProductsJob first."
          end
          
          stats[:processed] += 1
          task.increment_processed!
          
        rescue => e
          Rails.logger.error "ParseBestsellersJob: Error processing bestseller #{product_data['id'] || product_data[:id]}: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
          stats[:errors] += 1
          task.increment_errors!
        end
      end
    rescue => e
      Rails.logger.error "ParseBestsellersJob: Error fetching products for category #{category.ikea_id}: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      stats[:errors] += 1
      task.increment_errors!
    end
  end
end


