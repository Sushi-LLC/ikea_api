# Локальное хранилище изображений (текущая реализация)
require 'digest/sha1'
require 'fileutils'
require 'net/http'
require 'uri'

module ImageStorage
  class Local < Base
    BASE_STORAGE_PATH = Rails.root.join('public', 'images').freeze
    CATEGORIES_PATH = BASE_STORAGE_PATH.join('categories').freeze
    PRODUCTS_PATH = BASE_STORAGE_PATH.join('products').freeze
    
    class << self
      def upload(image_url, product_sku: nil, category_id: nil)
        return nil unless image_url.present?
        
        # Нормализуем URL
        normalized_url = normalize_url(image_url)
        return nil if normalized_url.empty?
        
        # Генерируем sharded path на основе SHA1 хеша URL
        hash = Digest::SHA1.hexdigest(normalized_url)
        ext = get_ext_from_url(normalized_url)
        sharded_path = build_sharded_path(hash, ext, product_sku: product_sku, category_id: category_id)
        
        # Проверяем, не существует ли уже файл
        return sharded_path[:rel] if File.exist?(sharded_path[:abs])
        
        # Создаем директорию и загружаем
        FileUtils.mkdir_p(File.dirname(sharded_path[:abs]))
        download_image(normalized_url, sharded_path[:abs])
        
        sharded_path[:rel]
      rescue => e
        Rails.logger.error "ImageStorage::Local: Failed to upload image #{image_url}: #{e.message}"
        nil
      end
      
      def exists?(path)
        return false unless path.present?
        File.exist?(Rails.root.join('public', path))
      end
      
      def url(path)
        return nil unless path.present?
        # Для локального хранилища возвращаем относительный путь
        path.start_with?('/') ? path : "/#{path}"
      end
      
      def delete(path)
        return false unless path.present?
        file_path = Rails.root.join('public', path)
        File.delete(file_path) if File.exist?(file_path)
        true
      rescue => e
        Rails.logger.error "ImageStorage::Local: Failed to delete image #{path}: #{e.message}"
        false
      end
      
      private
      
      def normalize_url(image_url)
        url = image_url.to_s.strip
        return '' if url.empty?
        
        # Преобразуем относительные URL в абсолютные
        unless url.start_with?('http')
          url = "https://www.ikea.com#{url}" if url.start_with?('/')
        end
        
        url
      end
      
      def build_sharded_path(hash, ext, product_sku: nil, category_id: nil)
        a = hash[0..1]
        b = hash[2..3]
        c = hash[4..5]
        filename = "#{hash}#{ext}"
        
        if category_id
          rel_path = File.join('images', 'categories', "#{category_id}.jpg")
          abs_path = Rails.root.join('public', rel_path)
        else
          rel_path = File.join('images', 'products', a, b, c, filename)
          abs_path = Rails.root.join('public', rel_path)
        end
        
        { rel: rel_path.gsub(/\\/, '/'), abs: abs_path }
      end
      
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
end

