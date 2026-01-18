module Api
  module V1
    class CartPromoController < ApplicationController
      include CartResponseFormatter

      def apply
        cart, token, _ = CartTokenResolver.call(request: request, params: params)
        code = params.require(:code).strip.upcase
        promo = PromoCode.find_by(code: code)

        unless promo&.active_now?
          return render json: { error: 'invalid_promo_code' }, status: :unprocessable_entity
        end

        cart.update!(promo_code: promo)
        cart.touch_expiration!

        render json: cart_response_payload(cart, token)
      end

      def remove
        cart, token, _ = CartTokenResolver.call(request: request, params: params)
        cart.update!(promo_code_id: nil)
        cart.touch_expiration!

        render json: cart_response_payload(cart, token)
      end
    end
  end
end
