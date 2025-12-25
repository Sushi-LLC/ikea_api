# Задача для парсинга популярных категорий
# Обновляет флаг is_popular на основе данных из API IKEA
class ParsePopularCategoriesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, task_id: nil)
    # Если task_id передан, используем существующую задачу, иначе создаем новую
    task = task_id ? ParserTask.find(task_id) : create_parser_task('popular_categories', limit: limit)
    
    # Проверяем, не остановлена ли задача перед началом выполнения
    check_task_not_stopped!(task)
    
    task.mark_as_running!
    
    notify_started('popular_categories', limit: limit)
    start_time = Time.current
    
    stats = {
      processed: 0,
      created: 0,
      updated: 0,
      errors: 0
    }
    
    begin
      # Сначала пробуем получить с главной страницы через scrape.do
      Rails.logger.info "ParsePopularCategoriesJob: Fetching popular categories from homepage via scrape.do"
      homepage_data = HomepageFetcher.fetch
      popular_category_ids = homepage_data[:popular_category_ids] || []
      
      # Если не получилось с главной страницы, используем старый метод
      if popular_category_ids.empty?
        Rails.logger.info "ParsePopularCategoriesJob: No popular categories from homepage, trying PopularCategoriesFetcher"
        popular_category_ids = PopularCategoriesFetcher.fetch
      else
        Rails.logger.info "ParsePopularCategoriesJob: Found #{popular_category_ids.length} popular categories from homepage"
      end
      
      if popular_category_ids.empty?
        Rails.logger.warn "ParsePopularCategoriesJob: No popular categories found via fetcher, trying API fallback"
        # Fallback: получаем из API и ищем флаг isPopular
        categories_data = IkeaApiService.fetch_categories
        if categories_data
          process_popular_categories_from_api(categories_data, task, stats, limit)
        else
          error_msg = 'Failed to fetch popular categories'
          Rails.logger.error "ParsePopularCategoriesJob: #{error_msg}"
          raise StandardError, error_msg
        end
      else
        # Обновляем флаги is_popular для найденных категорий
        process_popular_category_ids(popular_category_ids, task, stats, limit)
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('popular_categories', stats)
      
    rescue StandardError => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "ParsePopularCategoriesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "ParsePopularCategoriesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('popular_categories', e)
      raise
    rescue => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "ParsePopularCategoriesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "ParsePopularCategoriesJob unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!("Unexpected error: #{e.message}")
      notify_error('popular_categories', e)
    end
  end

  private

  def process_popular_category_ids(category_ids, task, stats, limit)
    Rails.logger.info "ParsePopularCategoriesJob: Processing #{category_ids.length} popular category IDs"
    Rails.logger.info "ParsePopularCategoriesJob: First 10 IDs: #{category_ids.first(10).inspect}"
    
    # Сначала сбрасываем все флаги is_popular
    Category.update_all(is_popular: false)
    Rails.logger.info "ParsePopularCategoriesJob: Reset all is_popular flags to false"
    
    found_count = 0
    not_found_ids = []
    
      # Устанавливаем is_popular для найденных категорий
      category_ids.each do |category_id|
        break if limit && stats[:processed] >= limit
        
        check_task_not_stopped!(task)
        
        # Нормализуем ID (убираем лишние символы, пробелы)
        normalized_id = category_id.to_s.strip
        
        # Пробуем найти категорию по разным вариантам ID
        # 1. Точное совпадение
        category = Category.find_by(ikea_id: normalized_id) || 
                   Category.find_by(ikea_id: normalized_id.downcase) ||
                   Category.find_by(ikea_id: normalized_id.upcase)
        
        # 2. Если UUID не найден, пробуем найти по числовому ID (если UUID содержит путь)
        unless category
          # Если это UUID с путем (например, "parent-id/child-id"), пробуем найти по child-id
          if normalized_id.include?('/') && !normalized_id.start_with?('http')
            parts = normalized_id.split('/')
            category = Category.find_by(ikea_id: parts.last) if parts.length > 1
          end
          
          # Пробуем частичное совпадение
          category ||= Category.where("ikea_id LIKE ?", "%#{normalized_id}%").first
          category ||= Category.where("ikea_id LIKE ?", "%#{normalized_id.gsub('-', '')}%").first
          
          # Поиск по URL (если это полный URL или slug категории)
          if normalized_id.start_with?('http') || normalized_id.start_with?('/')
            # Это полный URL или путь
            url_to_search = normalized_id.start_with?('http') ? normalized_id : "https://www.ikea.com#{normalized_id}"
            
            # Пробуем найти по части URL (slug)
            if url_to_search.include?('/cat/')
              slug = url_to_search.split('/cat/').last.split('/').first
              if slug.present?
                # Ищем по slug (например, "gotowanie-i-zastawa-stolowa-kt001")
                category ||= Category.where("url LIKE ?", "%#{slug}%").first
                # Пробуем найти по последней части slug (например, "kt001")
                slug_parts = slug.split('-')
                if slug_parts.length > 1
                  category ||= Category.where("url LIKE ?", "%#{slug_parts.last}%").first
                end
              end
            end
            
            # Пробуем найти по полному URL
            category ||= Category.where("url LIKE ?", "%#{url_to_search}%").first
            category ||= Category.where("url LIKE ?", "%#{normalized_id}%").first
          elsif normalized_id.include?('-') && !normalized_id.match(/^[0-9a-f]{8}-/)
            # Это похоже на slug (например, "gotowanie-i-zastawa-stolowa-kt001")
            category ||= Category.where("url LIKE ?", "%#{normalized_id}%").first
            # Пробуем найти по части slug
            slug_parts = normalized_id.split('-')
            if slug_parts.length > 1
              category ||= Category.where("url LIKE ?", "%#{slug_parts.last}%").first
            end
          end
        end
      
      if category
        unless category.is_popular
          category.update!(is_popular: true)
          stats[:updated] += 1
          task.increment_updated!
          found_count += 1
          Rails.logger.info "ParsePopularCategoriesJob: Marked category #{category.name} (ID: #{category.ikea_id}) as popular (found by: #{normalized_id})"
        end
      else
        not_found_ids << normalized_id
        Rails.logger.debug "ParsePopularCategoriesJob: Category with ID '#{normalized_id}' not found in database"
      end
      
      stats[:processed] += 1
      task.increment_processed!
    end
    
    Rails.logger.info "ParsePopularCategoriesJob: Found #{found_count} categories, #{not_found_ids.length} not found"
    if not_found_ids.length > 0 && not_found_ids.length <= 20
      Rails.logger.warn "ParsePopularCategoriesJob: Not found IDs (first 20): #{not_found_ids.first(20).inspect}"
    end
  end
  
  def process_popular_categories_from_api(nodes, task, stats, limit, parent_ids: [])
    return if limit && stats[:processed] >= limit
    
    # Проверяем, не остановлена ли задача
    check_task_not_stopped!(task)
    
    Array(nodes).each do |node|
      break if limit && stats[:processed] >= limit
      
      # Проверяем статус задачи в каждой итерации
      check_task_not_stopped!(task)
      
      ikea_id = node['id'] || node['categoryId']
      next unless ikea_id
      
      category = Category.find_by(ikea_id: ikea_id)
      
      if category
        # Извлекаем флаг isPopular из API ответа
        is_popular = node['isPopular'] || 
                     node['is_popular'] || 
                     node['popular'] || 
                     false
        
        was_popular = category.is_popular
        
        # Обновляем только если значение изменилось
        if was_popular != is_popular
          category.update!(is_popular: is_popular)
          stats[:updated] += 1
          task.increment_updated!
          Rails.logger.info "ParsePopularCategoriesJob: Updated category #{category.name} (ID: #{ikea_id}) - is_popular: #{was_popular} -> #{is_popular}"
        end
      end
      
      stats[:processed] += 1
      task.increment_processed!
      
      # Рекурсивно обрабатываем дочерние категории
      children = node['subs'] || node['children']
      if children && children.any?
        new_parent_ids = parent_ids + [ikea_id]
        process_popular_categories_from_api(children, task, stats, limit, parent_ids: new_parent_ids)
      end
    end
  end
end


