# Задача для парсинга хитов продаж
class ParseBestsellersJob < ApplicationJob
  queue_as :parser

  def perform(limit: nil)
    task = create_parser_task('bestsellers', limit: limit)
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
      # Хиты продаж - это продукты с флагом is_bestseller
      # Получаем их из специальной категории или помечаем существующие
      # В данном случае обновляем флаг is_bestseller для существующих продуктов
      
      # Можно использовать специальную категорию или API endpoint для хитов
      # Здесь упрощенная версия - обновляем флаги на основе данных из API
      
      categories = Category.active.limit(limit || 100)
      
      categories.find_each do |category|
        break if limit && stats[:processed] >= limit
        
        process_bestsellers_for_category(category, task, stats, limit)
      end
      
      task.mark_as_completed!(stats)
      stats[:duration] = Time.current - start_time
      notify_completed('bestsellers', stats)
      
    rescue => e
      Rails.logger.error "ParseBestsellersJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      task.mark_as_failed!(e.message)
      notify_error('bestsellers', e)
      raise
    end
  end

  private

  def process_bestsellers_for_category(category, task, stats, limit)
    products_data = IkeaApiService.search_products_by_category(
      category.ikea_id,
      offset: 0,
      limit: 50
    )
    
    products_data.each do |product_data|
      break if limit && stats[:processed] >= limit
      
      begin
        sku = product_data['id']
        product = Product.find_by(sku: sku)
        
        if product
          # Помечаем как хит продаж, если есть специальный флаг в API
          # Или используем другую логику определения
          was_bestseller = product.is_bestseller
          product.update!(is_bestseller: true) # Упрощенная логика
          
          if was_bestseller != product.is_bestseller
            stats[:updated] += 1
            task.increment_updated!
          end
        else
          # Создаем новый продукт с флагом bestseller
          Product.create!(
            sku: sku,
            name: product_data['typeName'],
            item_no: product_data['itemNoGlobal'] || product_data['itemNo'],
            url: "https://www.ikea.com#{product_data['pipUrl']}",
            price: product_data.dig('salesPrice', 'numeral'),
            category_id: category.ikea_id,
            is_bestseller: true
          )
          stats[:created] += 1
          task.increment_created!
        end
        
        stats[:processed] += 1
        task.increment_processed!
        
      rescue => e
        Rails.logger.error "Error processing bestseller #{product_data['id']}: #{e.message}"
        stats[:errors] += 1
        task.increment_errors!
      end
    end
  end
end


