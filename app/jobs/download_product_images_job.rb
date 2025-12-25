# Задача для загрузки изображений продуктов
class DownloadProductImagesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, product_id: nil, images_limit: nil, task_id: nil)
    # Если task_id передан, используем существующую задачу, иначе создаем новую
    task = task_id ? ParserTask.find(task_id) : create_parser_task('product_images', limit: limit)
    
    # Проверяем, не остановлена ли задача перед началом выполнения
    check_task_not_stopped!(task)
    
    task.mark_as_running!
    
    notify_started('product_images', limit: limit)
    start_time = Time.current
    
    stats = {
      processed: 0,
      created: 0,
      updated: 0,
      errors: 0
    }
    
    begin
      products = if product_id
                   Product.where(sku: product_id)
                 else
                   # Ищем продукты с непустыми images (массив или JSON строка)
                   Product.where.not(images: nil)
                          .where("images != '[]' AND images != '' AND images != 'null'")
                          .limit(limit || 1000)
                 end
      
      products.find_each do |product|
        break if limit && stats[:processed] >= limit
        
        # Проверяем, не остановлена ли задача
        check_task_not_stopped!(task)
        
        # Получаем массив URL изображений
        image_urls = if product.images.is_a?(Array)
                      product.images
                    elsif product.images.is_a?(String)
                      begin
                        parsed = JSON.parse(product.images)
                        parsed.is_a?(Array) ? parsed : []
                      rescue
                        []
                      end
                    else
                      []
                    end
        
        next if image_urls.empty?
        
        begin
          result = ImageDownloader.download_product_images(product, image_urls, limit: images_limit)
          
          if result.any?
            stats[:updated] += 1
            task.increment_updated!
          end
          
          stats[:processed] += 1
          task.increment_processed!
        rescue => e
          Rails.logger.error "Error downloading images for product #{product.sku}: #{e.message}"
          stats[:errors] += 1
          task.increment_errors!
        end
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('product_images', stats)
      
    rescue StandardError => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "DownloadProductImagesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "DownloadProductImagesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('product_images', e)
      raise
    rescue => e
      # Если задача была остановлена вручную - просто прерываем выполнение
      if e.message == 'Task was stopped manually'
        Rails.logger.info "DownloadProductImagesJob: Task #{task.id} was stopped manually, aborting"
        return
      end
      
      Rails.logger.error "DownloadProductImagesJob unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      task.mark_as_failed!("Unexpected error: #{e.message}")
      notify_error('product_images', e)
    end
  end
end


