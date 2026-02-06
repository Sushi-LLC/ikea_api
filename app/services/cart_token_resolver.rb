class CartTokenResolver
  def self.call(request:, params:, user: nil)
    # 1. Если есть пользователь, возвращаем его корзину
    if user
      cart = user.cart || user.create_cart!(expires_at: 1.year.from_now, guest_token: SecureRandom.hex(24))
      return [cart, cart.guest_token, false] 
    end

    # 2. Иначе работаем как раньше с гостевыми токенами
    token = request.headers['X-Cart-Token'].presence || params[:cart_token].presence
    return new_cart_response if token.blank?

    cart = Cart.find_by(guest_token: token)
    return new_cart_response if cart.nil? || cart.expired?

    [cart, token, false]
  end

  def self.new_cart_response
    cart = Cart.create!
    [cart, cart.guest_token, true]
  end
  private_class_method :new_cart_response
end
