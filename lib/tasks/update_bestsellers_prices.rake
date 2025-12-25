namespace :products do
  desc "Обновить цены для всех продуктов 'Хиты продаж' через IKEA API"
  task update_bestsellers_prices: :environment do
    puts "=== ОБНОВЛЕНИЕ ЦЕН ДЛЯ 'ХИТЫ ПРОДАЖ' ==="
    puts ""
    
    # Находим все продукты с флагом is_bestseller
    bestsellers = Product.where(is_bestseller: true)
    total_count = bestsellers.count
    
    puts "Найдено продуктов 'Хиты продаж': #{total_count}"
    puts ""
    
    if total_count == 0
      puts "⚠️  Нет продуктов с флагом is_bestseller = true"
      puts "   Запустите сначала ParseBestsellersJob для установки флагов"
      exit
    end
    
    stats = {
      processed: 0,
      updated: 0,
      errors: 0,
      no_item_no: 0
    }
    
    # Группируем продукты по категориям для более эффективного запроса
    bestsellers_by_category = bestsellers.includes(:category).group_by(&:category_id)
    
    bestsellers_by_category.each do |category_id, products|
      category = products.first.category
      next unless category
      
      puts "📦 Категория: #{category.name} (#{products.length} продуктов)"
      
      # Получаем продукты через API поиска по категории
      begin
        products_data = []
        
        # Если category_id не UUID, пробуем API поиска
        unless category.ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) || category.ikea_id.to_s.include?('/')
          products_data = IkeaApiService.search_products_by_category(
            category.ikea_id,
            offset: 0,
            limit: 100
          )
        end
        
        if products_data.any?
          # Создаем индекс по SKU для быстрого поиска
          products_by_sku = {}
          products.each { |p| products_by_sku[p.sku.gsub(/[.\-\s]/, '')] = p }
          
          products_data.each do |product_data|
            # Нормализуем SKU из API ответа
            api_sku = product_data['id'] || product_data[:id] || product_data['sku'] || product_data[:sku]
            next unless api_sku.present?
            
            normalized_sku = api_sku.to_s.gsub(/[.\-\s]/, '')
            product = products_by_sku[normalized_sku]
            
            next unless product
            
            stats[:processed] += 1
            
            # Извлекаем цену из разных мест в ответе API
            price = product_data.dig('salesPrice', 'numeral') || 
                    product_data.dig(:salesPrice, :numeral) ||
                    product_data.dig('salesPrice', :numeral) ||
                    product_data.dig(:salesPrice, 'numeral') ||
                    product_data.dig('price', 'numeral') || 
                    product_data.dig(:price, :numeral) ||
                    product_data['price'] || 
                    product_data[:price]
            
            if price.present?
              old_price = product.price
              product.update_column(:price, price.to_f)
              puts "  ✓ #{product.name} (SKU: #{product.sku}): #{old_price || 'нет'} → #{price}"
              stats[:updated] += 1
            else
              puts "  ⚠️  #{product.name} (SKU: #{product.sku}): цена не найдена в API ответе"
              stats[:errors] += 1
            end
          end
        else
          # Если API не вернул продукты, обновляем через индивидуальные запросы
          puts "  ⚠️  API не вернул продукты, обновляем индивидуально..."
          products.each do |product|
            update_product_price(product, stats)
          end
        end
      rescue => e
        puts "  ❌ Ошибка при обработке категории: #{e.message}"
        # Fallback: обновляем индивидуально
        products.each do |product|
          update_product_price(product, stats)
        end
      end
      
      puts ""
    end
    
    # Обрабатываем продукты без категории
    products_without_category = bestsellers.where(category_id: nil)
    if products_without_category.any?
      puts "📦 Продукты без категории: #{products_without_category.count}"
      products_without_category.each do |product|
        update_product_price(product, stats)
      end
      puts ""
    end
    
    puts ""
    puts "=== ИТОГИ ==="
    puts "Обработано: #{stats[:processed]}"
    puts "Обновлено: #{stats[:updated]}"
    puts "Ошибок: #{stats[:errors]}"
    puts "Без item_no: #{stats[:no_item_no]}"
    puts ""
  end
  
  private
  
  def update_product_price(product, stats)
    stats[:processed] += 1
    
    begin
      # Проверяем наличие item_no
      if product.item_no.blank?
        puts "  ⚠️  #{product.name} (SKU: #{product.sku}): нет item_no"
        stats[:no_item_no] += 1
        return
      end
      
      # Пробуем получить цену через URL (более надежный способ)
      update_price_from_url(product, stats)
    rescue => e
      puts "  ❌ #{product.name} (SKU: #{product.sku}): #{e.message}"
      stats[:errors] += 1
    end
  end
  
  def update_price_from_url(product, stats)
    return unless product.url.present?
    
    begin
      product_url = product.url.start_with?('http') ? product.url : "https://www.ikea.com#{product.url}"
      
      # Парсим страницу через PlDetailsFetcher
      pl_details = PlDetailsFetcher.fetch(product_url)
      
      if pl_details.present? && pl_details[:price].present?
        old_price = product.price
        product.update_column(:price, pl_details[:price].to_f)
        puts "  ✓ #{product.name} (SKU: #{product.sku}): #{old_price || 'нет'} → #{pl_details[:price]} (из URL)"
        stats[:updated] += 1
      else
        puts "  ⚠️  #{product.name} (SKU: #{product.sku}): цена не найдена на странице"
        stats[:errors] += 1
      end
    rescue => e
      puts "  ❌ #{product.name} (SKU: #{product.sku}): ошибка при парсинге URL - #{e.message}"
      stats[:errors] += 1
    end
  end
end

