# Сервис для загрузки изображений
require 'net/http'
require 'uri'
require 'fileutils'

class ImageDownloader
  BASE_STORAGE_PATH = Rails.root.join('public', 'images').freeze
  CATEGORIES_PATH = BASE_STORAGE_PATH.join('categories').freeze
  PRODUCTS_PATH = BASE_STORAGE_PATH.join('products').freeze

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
      
      downloaded = []
      urls = limit ? image_urls.first(limit) : image_urls
      
      urls.each_with_index do |image_url, index|
        next unless image_url.present?
        
        begin
          file_path = PRODUCTS_PATH.join(product.sku, "#{index + 1}.jpg")
          FileUtils.mkdir_p(file_path.dirname)
          
          download_image(image_url, file_path)
          
          relative_path = file_path.relative_path_from(Rails.root.join('public'))
          downloaded << relative_path.to_s
        rescue => e
          Rails.logger.error "Failed to download product image #{image_url}: #{e.message}"
        end
      end
      
      # Обновляем список локальных изображений
      if downloaded.any?
        product.update_column(:local_images, downloaded.to_json)
        product.update_column(:images_stored, downloaded.length)
      end
      
      downloaded
    end

    private

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

