class CheckoutService
  MIN_ORDER_AMOUNT = 150.0

  def self.call(user:, params:)
    cart = user.cart
    return { error: 'Корзина не найдена' } unless cart
    return { error: 'Корзина пуста' } if cart.cart_items.blank?

    # Пересчет и проверка с использованием динамических правил
    pricing = CartPricingService.call(cart: cart)
    
    unless pricing[:meta][:can_checkout]
      return { error: pricing[:meta][:min_order_error] }
    end

    # Проверка наличия (заглушка)
    pricing[:items].each do |item|
      # Проверяем реальный сток в БД, если есть поле quantity
      product = Product.find_by(sku: item[:sku])
      if product && product.quantity.to_i <= 0
        return { error: "Товара #{product.name} нет в наличии" }
      end
    end

    # Создание заказа
    order = nil
    
    Order.transaction do
      order = Order.new(
        user: user,
        status: :created,
        total_amount: pricing[:totals][:subtotal_new_byn],
        delivery_price: 0, # Пока 0, можно брать из params если передали
        discount_amount: pricing[:totals][:discount_total_byn],
        promo_code: cart.promo_code,
        full_name: params[:full_name],
        phone: params[:phone],
        delivery_type: params[:delivery_type],
        payment_method: params[:payment_method],
        address_json: params[:address] || {}
      )

      if order.save
        # Перенос товаров
        cart.cart_items.each do |cart_item|
          price_snapshot = pricing[:items].find { |i| i[:sku] == cart_item.product_sku }
          
          OrderItem.create!(
            order: order,
            product_sku: cart_item.product_sku,
            quantity: cart_item.quantity,
            price: price_snapshot[:unit_price_new_byn] # Фиксируем финальную цену
          )
        end

        # Очистка корзины
        cart.cart_items.destroy_all
        cart.update!(promo_code: nil)
      else
        raise ActiveRecord::Rollback
      end
    end

    if order&.persisted?
      # Здесь можно отправить email/sms/telegram
      { success: true, order: order }
    else
      { error: order&.errors&.full_messages&.join(', ') || 'Ошибка создания заказа' }
    end
  end
end
