# Сервис для загрузки изображений
require 'net/http'
require 'uri'
require 'fileutils'
require 'digest/sha1'

class ImageDownloader
  BASE_STORAGE_PATH = Rails.root.join('public', 'images').freeze
  CATEGORIES_PATH = BASE_STORAGE_PATH.join('categories').freeze
  PRODUCTS_PATH = BASE_STORAGE_PATH.join('products').freeze
  
  # Конкурентность загрузки (можно настроить через ENV)
  CONCURRENCY_IMAGES = ENV.fetch('IMG_DL_IMAGES', '6').to_i

  class << self
    # Загрузить изображение категории
    def download_category_image(category, image_url)
      return nil unless image_url.present?
      
      begin
        file_path = CATEGORIES_PATH.join("#{category.ikea_id}.jpg")
        FileUtils.mkdir_p(CATEGORIES_PATH)
        
        download_image(image_url, file_path)
        
        # Сохраняем относительный путь для использования в приложении
        relative_path = file_path.relative_path_from(Rails.root.join('public'))
        category.update_column(:local_image_path, relative_path.to_s)
        
        relative_path.to_s
      rescue => e
        Rails.logger.error "Failed to download category image #{image_url}: #{e.message}"
        nil
      end
    end

    # Загрузить изображения продукта
    def download_product_images(product, image_urls, limit: nil)
      return [] unless image_urls.present?
      
      # Нормализуем image_urls - может быть массив или строка (JSON)
      urls = if image_urls.is_a?(String)
               begin
                 JSON.parse(image_urls)
               rescue JSON::ParserError
                 Rails.logger.warn "ImageDownloader: Failed to parse image_urls JSON: #{image_urls[0..100]}"
                 []
               end
             else
               Array(image_urls)
             end
      
      return [] if urls.empty?
      
      # Получаем уже загруженные изображения
      existing_local_images = if product.local_images.is_a?(String)
                                begin
                                  JSON.parse(product.local_images) || []
                                rescue JSON::ParserError
                                  []
                                end
                              else
                                Array(product.local_images) || []
                              end
      
      local_paths = Set.new(existing_local_images)
      downloaded = 0
      failed = 0
      urls_to_download = limit ? urls.first(limit) : urls
      
      Rails.logger.info "ImageDownloader: Starting download of #{urls_to_download.length} images for product #{product.sku} (existing: #{local_paths.size})"
      
      # Параллельная загрузка с ограничением конкурентности
      mutex = Mutex.new
      threads = []
      active_threads = 0
      
      urls_to_download.each do |image_url|
        next unless image_url.present?
        
        # Ждем, пока освободится место для нового потока
        while active_threads >= CONCURRENCY_IMAGES
          sleep(0.1)
        end
        
        threads << Thread.new do
          mutex.synchronize { active_threads += 1 }
          
          begin
            # Нормализуем URL
            normalized_url = image_url.to_s.strip
            next if normalized_url.empty?
            
            # Преобразуем относительные URL в абсолютные
            unless normalized_url.start_with?('http')
              normalized_url = "https://www.ikea.com#{normalized_url}" if normalized_url.start_with?('/')
            end
            
            # Генерируем sharded path на основе SHA1 хеша URL
            hash = Digest::SHA1.hexdigest(normalized_url)
            ext = get_ext_from_url(normalized_url)
            sharded_path = build_sharded_path(hash, ext)
            
            # Проверяем, не существует ли уже файл
            if File.exist?(sharded_path[:abs])
              mutex.synchronize do
                local_paths.add(sharded_path[:rel])
              end
              Rails.logger.debug "ImageDownloader: Image already exists for #{product.sku}: #{sharded_path[:rel]}"
              next
            end
            
            # Создаем директорию и загружаем
            FileUtils.mkdir_p(File.dirname(sharded_path[:abs]))
            download_image(normalized_url, sharded_path[:abs])
            
            mutex.synchronize do
              local_paths.add(sharded_path[:rel])
              downloaded += 1
            end
            Rails.logger.debug "ImageDownloader: Successfully downloaded image for #{product.sku}: #{sharded_path[:rel]}"
          rescue => e
            mutex.synchronize { failed += 1 }
            Rails.logger.error "ImageDownloader: Failed to download product image #{image_url} for #{product.sku}: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
          ensure
            mutex.synchronize { active_threads -= 1 }
          end
        end
      end
      
      # Ждем завершения всех потоков
      threads.each(&:join)
      
      # Обновляем данные продукта
      images_total = urls.length
      images_stored = local_paths.size
      images_incomplete = images_stored < images_total
      local_images_array = local_paths.to_a
      
      # Обновляем только если что-то изменилось
      if downloaded > 0 || images_incomplete != product.images_incomplete || local_images_array != existing_local_images
        product.update_columns(
          local_images: local_images_array.to_json,
          images_stored: images_stored,
          images_total: images_total,
          images_incomplete: images_incomplete
        )
        Rails.logger.info "ImageDownloader: Product #{product.sku} - downloaded: #{downloaded}, failed: #{failed}, total: #{images_total}, stored: #{images_stored}, incomplete: #{images_incomplete}"
      end
      
      local_images_array
    end

    private

    # Генерирует sharded path для файла на основе хеша
    # Пример: hash=abcdef... -> ab/cd/ef/abcdef.jpg
    def build_sharded_path(hash, ext)
      a = hash[0..1]
      b = hash[2..3]
      c = hash[4..5]
      filename = "#{hash}#{ext}"
      rel_path = File.join('images', 'products', a, b, c, filename)
      abs_path = Rails.root.join('public', rel_path)
      { rel: rel_path.gsub(/\\/, '/'), abs: abs_path }
    end
    
    # Определяет расширение файла из URL
    def get_ext_from_url(url)
      begin
        uri = URI.parse(url)
        base = File.basename(uri.path)
        ext = base.match(/\.(jpg|jpeg|png|webp|gif|avif)$/i)
        ext ? ".#{ext[1].downcase}" : '.jpg'
      rescue
        '.jpg'
      end
    end

    def download_image(url, file_path)
      ProxyRotator.with_proxy_retry do |proxy_options|
        uri = URI.parse(url)
        
        # Используем Net::HTTP для более гибкой работы с прокси
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = 30
        
        # Настраиваем прокси, если есть
        if proxy_options && proxy_options[:http_proxyaddr]
          http.proxy_from_env = false
          http.proxy_address = proxy_options[:http_proxyaddr]
          http.proxy_port = proxy_options[:http_proxyport]
          http.proxy_user = proxy_options[:http_proxyuser]
          http.proxy_pass = proxy_options[:http_proxypass]
        end
        
        request = Net::HTTP::Get.new(uri.path)
        request['User-Agent'] = ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
        
        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          File.binwrite(file_path, response.body)
        else
          raise StandardError, "HTTP error: #{response.code} #{response.message}"
        end
      end
    end

  end
end

