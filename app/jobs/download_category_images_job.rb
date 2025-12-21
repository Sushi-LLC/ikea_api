# Задача для загрузки изображений категорий
class DownloadCategoryImagesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, category_id: nil)
    task = create_parser_task('category_images', limit: limit)
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
      
    rescue => e
      Rails.logger.error "DownloadCategoryImagesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('category_images', e)
      raise
    end
  end
end


