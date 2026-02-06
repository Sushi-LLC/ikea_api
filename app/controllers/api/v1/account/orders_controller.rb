module Api
  module V1
    module Account
      class OrdersController < ApplicationController
        before_action :authenticate_user

        def index
          orders = current_user.orders.order(created_at: :desc)
          paginated = orders.page(params[:page]).per(params[:per_page] || 10)

          render json: OrderSerializer.new(paginated, {
            meta: {
              total: paginated.total_count,
              page: params[:page] || 1,
              per_page: params[:per_page] || 10
            }
          })
        end

        def show
          order = current_user.orders.find(params[:id])
          render json: OrderSerializer.new(order, include: [:order_items])
        end
      end
    end
  end
end
