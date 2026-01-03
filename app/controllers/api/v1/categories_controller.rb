module Api
  module V1
    class CategoriesController < ApplicationController
      def index
        categories = Category.active
        categories = categories.popular if params[:is_popular] == 'true'
        
        render json: CategorySerializer.new(categories)
      end
      
      def show
        category = Category.find_by(ikea_id: params[:id])
        render json: CategorySerializer.new(category)
      end
      
      def popular
        categories = Category.popular
        render json: CategorySerializer.new(categories)
      end
      
      def tree
        # Простая реализация дерева категорий
        categories = Category.active.includes(:products)
        render json: CategorySerializer.new(categories)
      end
      
      def map
        # Карта категорий: переведенное имя + ссылка + продукты
        categories = Category.active
                            .includes(:products)
                            .where.not(translated_name: nil)
                            .where.not(translated_name: '')
        
        render json: CategoryMapSerializer.new(categories, {
          include: [],
          meta: {
            total: categories.count,
            generated_at: Time.current.iso8601
          }
        })
      end
    end
  end
end

