# Задача для парсинга категорий
class ParseCategoriesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil)
    task = create_parser_task('categories', limit: limit)
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
        raise StandardError, 'Failed to fetch categories from IKEA API'
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('categories', stats)
      
    rescue => e
      Rails.logger.error "ParseCategoriesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('categories', e)
      # Не пробрасываем ошибку дальше, чтобы задача была помечена как failed
    end
  end

  private

  def process_categories(categories_data, task, stats, limit)
    process_category_tree(categories_data, task, stats, limit)
  end

  def process_category_tree(nodes, task, stats, limit, parent_ids: [])
    return if limit && stats[:processed] >= limit
    
    Array(nodes).each do |node|
      break if limit && stats[:processed] >= limit
      
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
        remote_image_url: node['imageUrl'] || node['remoteImageUrl'],
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
      if node['children'] && node['children'].any?
        new_parent_ids = parent_ids + [ikea_id]
        process_category_tree(node['children'], task, stats, limit, parent_ids: new_parent_ids)
      end
    end
  end
end


