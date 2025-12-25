# Задача для парсинга категорий
class ParseCategoriesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, task_id: nil)
    # Если task_id передан, используем существующую задачу, иначе создаем новую
    task = task_id ? ParserTask.find(task_id) : create_parser_task('categories', limit: limit)
    
    # Проверяем, не остановлена ли задача перед началом выполнения
    check_task_not_stopped!(task)
    
    task.mark_as_running!
    
    notify_started('categories', limit: limit)
    start_time = Time.current
    
    stats = {
      processed: 0,
      created: 0,
      updated: 0,
      errors: 0
    }
    
    begin
      categories_data = IkeaApiService.fetch_categories
      
      if categories_data
        process_categories(categories_data, task, stats, limit)
      else
        error_msg = 'Failed to fetch categories from IKEA API (response was nil)'
        Rails.logger.error "ParseCategoriesJob: #{error_msg}"
        raise StandardError, error_msg
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('categories', stats)
      
      # Автоматически запускаем загрузку изображений для категорий
      # Не передаем лимит, чтобы загрузить изображения для всех категорий с remote_image_url
      Rails.logger.info "ParseCategoriesJob: Starting automatic download of category images"
      DownloadCategoryImagesJob.perform_later(limit: nil)
      
    rescue StandardError => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "ParseCategoriesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      error_message = e.message
      
      # Проверяем, связана ли ошибка с прокси/Cloudflare
      if error_message.include?('403') || error_message.include?('Cloudflare') || error_message.include?('Forbidden')
        error_message += "\n\n⚠️ Cloudflare блокирует запросы. Проверьте:\n"
        error_message += "1. Настроен ли PROXY_LIST в переменных окружения\n"
        error_message += "2. Работают ли прокси-серверы\n"
        error_message += "3. Доступен ли API IKEA через прокси\n"
        error_message += "\nПример настройки: export PROXY_LIST='http://proxy1:port,http://proxy2:port'"
      elsif error_message.include?('no proxies configured')
        error_message += "\n\n⚠️ Прокси не настроены. Установите PROXY_LIST в переменных окружения."
      end
      
      Rails.logger.error "ParseCategoriesJob error: #{error_message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!(error_message)
      notify_error('categories', e)
      # Не пробрасываем ошибку дальше, чтобы задача была помечена как failed
    rescue => e
      error_message = "Unexpected error: #{e.class} - #{e.message}"
      Rails.logger.error "ParseCategoriesJob unexpected error: #{error_message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!(error_message)
      notify_error('categories', e)
    end
  end

  private

  def process_categories(categories_data, task, stats, limit)
    process_category_tree(categories_data, task, stats, limit)
  end

  def process_category_tree(nodes, task, stats, limit, parent_ids: [])
    return if limit && stats[:processed] >= limit
    
    # Проверяем, не остановлена ли задача
    check_task_not_stopped!(task)
    
    Array(nodes).each do |node|
      break if limit && stats[:processed] >= limit
      
      # Проверяем статус задачи в каждой итерации
      check_task_not_stopped!(task)
      
      ikea_id = node['id'] || node['categoryId']
      next unless ikea_id
      
      category = Category.find_or_initialize_by(ikea_id: ikea_id)
      
      category_name = node['name'] || node['categoryName']
      
      # Перевод названия категории (только MyMemory)
      translated_name = if category_name.present?
                          begin
                            TranslationService.translate_with_my_memory(
                              category_name,
                              target_lang: 'ru',
                              source_lang: 'pl'
                            )
                          rescue => e
                            Rails.logger.warn("Translation failed for category #{category_name}: #{e.message}")
                            # Используем существующий перевод, если есть
                            category.translated_name || node['translatedName']
                          end
                        else
                          node['translatedName']
                        end
      
      category.assign_attributes(
        name: category_name,
        translated_name: translated_name,
        url: node['url'] || node['categoryUrl'],
        remote_image_url: node['im'] || node['imageUrl'] || node['remoteImageUrl'],
        parent_ids: parent_ids,
        is_deleted: false,
        is_important: node['isImportant'] || false,
        is_popular: node['isPopular'] || false
      )
      
      if category.new_record?
        category.save!
        stats[:created] += 1
      elsif category.changed?
        category.save!
        stats[:updated] += 1
      end
      
      stats[:processed] += 1
      task.increment_processed!
      
      # Рекурсивно обрабатываем дочерние категории
      # API возвращает дочерние категории в поле 'subs', а не 'children'
      children = node['subs'] || node['children']
      if children && children.any?
        new_parent_ids = parent_ids + [ikea_id]
        process_category_tree(children, task, stats, limit, parent_ids: new_parent_ids)
      end
    end
  end
end


