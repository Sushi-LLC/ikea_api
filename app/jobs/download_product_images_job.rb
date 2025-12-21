# Задача для загрузки изображений продуктов
class DownloadProductImagesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil, product_id: nil, images_limit: nil)
    task = create_parser_task('product_images', limit: limit)
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
      
    rescue => e
      Rails.logger.error "DownloadProductImagesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('product_images', e)
      raise
    end
  end
end


