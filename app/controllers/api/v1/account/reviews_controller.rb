module Api
  module V1
    module Account
      class ReviewsController < ApplicationController
        before_action :authenticate_user

        def index
          reviews = current_user.reviews
          reviews = reviews.where(status: params[:status]) if params[:status].present?
          reviews = reviews.order(created_at: :desc).includes(:product)

          paginated = reviews.page(params[:page]).per(params[:per_page] || 20)

          render json: ReviewSerializer.new(paginated, {
            params: serializer_params,
            meta: {
              total: paginated.total_count,
              page: params[:page] || 1,
              per_page: params[:per_page] || 20
            }
          })
        end

        def available
          purchased_skus = OrderItem.joins(:order)
                                    .merge(Order.purchased)
                                    .where(orders: { user_id: current_user.id })
                                    .distinct
                                    .pluck(:product_sku)

          reviewed_skus = current_user.reviews.pluck(:product_sku)
          skus = purchased_skus - reviewed_skus
          products = Product.where(sku: skus)

          payload = products.map do |product|
            {
              sku: product.sku,
              name: product.name,
              images: product.images || [],
              local_images: product.local_images || []
            }
          end

          render json: { data: payload }
        end

        private

        def serializer_params
          { host: request.base_url }
        end
      end
    end
  end
end
