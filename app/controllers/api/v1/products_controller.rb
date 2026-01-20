module Api
  module V1
    class ProductsController < ApplicationController
      before_action :authenticate_user, except: [:index, :show, :bestsellers, :popular]
      
      def index
        products = Product.includes(:category)
        products = products.by_rating if params[:sort] == 'rating'
        products = products.page(params[:page]).per(params[:per_page] || 50)
        
        render json: ProductSerializer.new(products, {
          include: [:category],
          meta: {
            total: products.total_count,
            page: params[:page] || 1,
            per_page: params[:per_page] || 50,
            sort: params[:sort]
          }
        })
      end
      
      def show
        product = Product.find_by(sku: params[:sku])
        render json: ProductSerializer.new(product, {
          include: [:category],
          params: { detail: true }
        })
      end
      
      def bestsellers
        products = Product.bestsellers
                         .includes(:category)
                         .page(params[:page])
                         .per(params[:per_page] || 10)
        
        render json: ProductSerializer.new(products, {
          include: [:category],
          meta: {
            total: products.total_count,
            page: params[:page] || 1
          }
        })
      end
      
      def popular
        products = Product.popular
                         .includes(:category)
                         .page(params[:page])
                         .per(params[:per_page] || 10)
        
        render json: ProductSerializer.new(products, {
          include: [:category],
          meta: {
            total: products.total_count,
            page: params[:page] || 1
          }
        })
      end
    end
  end
end

