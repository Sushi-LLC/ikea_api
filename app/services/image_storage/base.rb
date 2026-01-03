# Базовый класс для хранения изображений
# Наследуйте от этого класса для реализации различных хранилищ (локальное, S3, Cloudinary и т.д.)
module ImageStorage
  class Base
    class << self
      # Загрузить изображение по URL и сохранить
      # Возвращает относительный путь или URL для доступа к изображению
      def upload(image_url, product_sku: nil, category_id: nil)
        raise NotImplementedError, "Subclass must implement upload method"
      end
      
      # Проверить, существует ли изображение
      def exists?(path_or_url)
        raise NotImplementedError, "Subclass must implement exists? method"
      end
      
      # Получить URL для доступа к изображению
      def url(path_or_url)
        raise NotImplementedError, "Subclass must implement url method"
      end
      
      # Удалить изображение
      def delete(path_or_url)
        raise NotImplementedError, "Subclass must implement delete method"
      end
    end
  end
end

