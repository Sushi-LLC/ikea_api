# Задача для парсинга популярных категорий
class ParsePopularCategoriesJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil)
    task = create_parser_task('popular_categories', limit: limit)
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
      # Обновляем флаг is_popular для категорий
      # Можно использовать специальную логику или API endpoint
      
      categories = Category.active.limit(limit || 1000)
      
      categories.find_each do |category|
        break if limit && stats[:processed] >= limit
        
        begin
          # Упрощенная логика - помечаем категории с большим количеством продуктов как популярные
          products_count = Product.where(category_id: category.ikea_id).count
          
          was_popular = category.is_popular
          category.update!(is_popular: products_count >= 10) # Порог 10 продуктов
          
          if was_popular != category.is_popular
            stats[:updated] += 1
            task.increment_updated!
          end
          
          stats[:processed] += 1
          task.increment_processed!
          
        rescue => e
          Rails.logger.error "Error processing popular category #{category.ikea_id}: #{e.message}"
          stats[:errors] += 1
          task.increment_errors!
        end
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('popular_categories', stats)
      
    rescue => e
      Rails.logger.error "ParsePopularCategoriesJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('popular_categories', e)
      raise
    end
  end
end


