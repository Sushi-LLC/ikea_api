class CartPricingService
  def self.call(cart:)
    promo = cart.promo_code
    promo_valid = promo&.active_now?

    items = cart.cart_items.includes(:product).map do |item|
      product_price = item.product&.price || 0
      quantity = item.quantity
      promo_applied = promo_valid && promo.applies_to_sku?(item.product_sku)
      unit_discount = promo_applied ? calculate_unit_discount(promo, product_price) : 0
      unit_discount = [unit_discount, product_price].min
      unit_price_new = [product_price - unit_discount, 0].max
      line_total_old = product_price * quantity
      line_total_new = unit_price_new * quantity

      {
        sku: item.product_sku,
        quantity: quantity,
        unit_price_old_byn: product_price,
        unit_price_new_byn: unit_price_new,
        unit_discount_byn: unit_discount,
        line_total_old_byn: line_total_old,
        line_total_new_byn: line_total_new,
        line_discount_byn: line_total_old - line_total_new,
        promo_applied: promo_applied,
        promo_code: promo_applied ? promo.code : nil
      }
    end

    subtotal_old = items.sum { |entry| entry[:line_total_old_byn] }
    subtotal_new = items.sum { |entry| entry[:line_total_new_byn] }
    discount_total = subtotal_old - subtotal_new
    total_weight = cart.cart_items.joins(:product).sum('products.weight * cart_items.quantity')
    
    # Logic from requirements using dynamic rules
    rules = CartRulesService.call(subtotal_new_byn: subtotal_new)

    {
      items: items,
      totals: {
        subtotal_old_byn: subtotal_old,
        subtotal_new_byn: subtotal_new,
        discount_total_byn: discount_total,
        total_weight_kg: total_weight.to_f
      },
      promo: {
        code: promo&.code,
        valid: promo_valid
      },
      meta: {
        min_order_amount: rules[:rules][:min_order_amount_byn],
        can_checkout: rules[:flags][:checkout_allowed],
        min_order_error: rules[:flags][:checkout_allowed] ? nil : "Оформление доступно от #{rules[:rules][:min_order_amount_byn]} руб.",
        free_delivery_threshold: rules[:rules][:free_delivery_threshold_byn],
        free_delivery_remaining: rules[:flags][:free_delivery_missing_byn]
      }
    }
  end

  def self.calculate_unit_discount(promo, price)
    return 0 unless promo && price.positive?

    case promo.discount_type
    when 'percent'
      (price * promo.discount_value / 100).round(2)
    when 'fixed_byn'
      [promo.discount_value, price].min
    else
      0
    end
  end
  private_class_method :calculate_unit_discount
end
