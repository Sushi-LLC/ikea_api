# Задача для загрузки изображений категорий
class DownloadCategoryImagesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, category_id: nil, task_id: nil)
    # Если task_id передан, используем существующую задачу, иначе создаем новую
    task = task_id ? ParserTask.find(task_id) : create_parser_task('category_images', limit: limit)
    
    # Проверяем, не остановлена ли задача перед началом выполнения
    check_task_not_stopped!(task)
    
    task.mark_as_running!
    
    notify_started('category_images', limit: limit)
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
                     Category.where.not(remote_image_url: nil)
                             .where(local_image_path: nil)
                             .limit(limit || 1000)
                   end
      
      categories.find_each do |category|
        break if limit && stats[:processed] >= limit
        
        # Проверяем, не остановлена ли задача
        check_task_not_stopped!(task)
        
        next unless category.remote_image_url.present?
        
        begin
          result = ImageDownloader.download_category_image(category, category.remote_image_url)
          
          if result
            stats[:updated] += 1
            task.increment_updated!
          end
          
          stats[:processed] += 1
          task.increment_processed!
          
        rescue => e
          Rails.logger.error "Error downloading image for category #{category.ikea_id}: #{e.message}"
          stats[:errors] += 1
          task.increment_errors!
        end
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('category_images', stats)
      
    rescue StandardError => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "DownloadCategoryImagesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "DownloadCategoryImagesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('category_images', e)
      raise
    rescue => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "DownloadCategoryImagesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "DownloadCategoryImagesJob unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!("Unexpected error: #{e.message}")
      notify_error('category_images', e)
    end
  end
end


