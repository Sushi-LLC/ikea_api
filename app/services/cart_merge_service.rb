class CartMergeService
  def self.call(guest_token:, user:)
    return if guest_token.blank? || user.nil?

    guest_cart = Cart.find_by(guest_token: guest_token)
    return unless guest_cart

    user_cart = user.cart || user.create_cart!(expires_at: 1.year.from_now, guest_token: SecureRandom.hex(24))

    Cart.transaction do
      guest_cart.cart_items.find_each do |guest_item|
        existing_item = user_cart.cart_items.find_by(product: guest_item.product)

        if existing_item
          existing_item.update!(quantity: existing_item.quantity + guest_item.quantity)
        else
          guest_item.update!(cart: user_cart)
        end
      end
      
      # Если у пользовательской корзины нет промокода, а у гостевой есть - переносим
      if user_cart.promo_code.nil? && guest_cart.promo_code.present?
        user_cart.update!(promo_code: guest_cart.promo_code)
      end

      # Удаляем старую гостевую корзину
      guest_cart.destroy!
    end
    
    user_cart
  end
end
