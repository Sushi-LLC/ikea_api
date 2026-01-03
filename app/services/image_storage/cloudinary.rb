# Cloudinary хранилище изображений (заготовка для будущей реализации)
# Требует gem 'cloudinary'
module ImageStorage
  class Cloudinary < Base
    class << self
      def upload(image_url, product_sku: nil, category_id: nil)
        # TODO: Реализовать загрузку в Cloudinary
        # Пример:
        # require 'cloudinary'
        # 
        # Cloudinary.config do |config|
        #   config.cloud_name = ENV['CLOUDINARY_CLOUD_NAME']
        #   config.api_key = ENV['CLOUDINARY_API_KEY']
        #   config.api_secret = ENV['CLOUDINARY_API_SECRET']
        # end
        # 
        # folder = category_id ? "categories" : "products"
        # public_id = generate_public_id(image_url, product_sku: product_sku, category_id: category_id)
        # 
        # result = Cloudinary::Uploader.upload(
        #   image_url,
        #   folder: folder,
        #   public_id: public_id,
        #   overwrite: false
        # )
        # 
        # return result['public_id']
        raise NotImplementedError, "Cloudinary storage not yet implemented"
      end
      
      def exists?(public_id)
        # TODO: Проверить существование в Cloudinary
        raise NotImplementedError, "Cloudinary storage not yet implemented"
      end
      
      def url(public_id)
        # TODO: Вернуть URL Cloudinary
        # return Cloudinary::Utils.cloudinary_url(public_id)
        raise NotImplementedError, "Cloudinary storage not yet implemented"
      end
      
      def delete(public_id)
        # TODO: Удалить из Cloudinary
        # Cloudinary::Uploader.destroy(public_id)
        raise NotImplementedError, "Cloudinary storage not yet implemented"
      end
    end
  end
end

