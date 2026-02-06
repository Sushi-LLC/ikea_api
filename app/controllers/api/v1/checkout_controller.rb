module Api
  module V1
    class CheckoutController < ApplicationController
      before_action :authenticate_user_strict

      def create
        result = CheckoutService.call(user: current_user, params: checkout_params)
        
        if result[:success]
          render json: { 
            message: 'Заказ успешно оформлен', 
            order_id: result[:order].id 
          }, status: :created
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      end

      private

      def authenticate_user_strict
        token = request.headers['Authorization']&.split(' ')&.last
        if token
          decoded = JwtService.decode(token)
          @current_user = User.find_by(id: decoded[:user_id]) if decoded
        end
        
        render json: { error: 'Необходима авторизация' }, status: :unauthorized unless @current_user
      end

      def checkout_params
        params.permit(:full_name, :phone, :delivery_type, :payment_method, address: {})
      end
    end
  end
end
