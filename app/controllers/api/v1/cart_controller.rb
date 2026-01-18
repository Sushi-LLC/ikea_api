module Api
  module V1
    class CartController < ApplicationController
      include CartResponseFormatter

      def show
        cart, token, _ = CartTokenResolver.call(request: request, params: params)
        apply_promo_from_param(cart)
        cart.touch_expiration!
        render json: cart_response_payload(cart, token)
      end

      def clear
        cart, token, _ = CartTokenResolver.call(request: request, params: params)
        cart.cart_items.destroy_all
        cart.touch_expiration!
        render json: cart_response_payload(cart, token)
      end

      private

      def apply_promo_from_param(cart)
        return if cart.promo_code_id.present?
        code = params[:promo_code].presence
        return unless code

        promo = PromoCode.find_by(code: code.strip.upcase)
        return unless promo&.active_now?

        cart.update!(promo_code: promo)
      end
    end
  end
end
