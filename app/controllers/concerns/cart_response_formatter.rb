module CartResponseFormatter
  private

  def cart_response_payload(cart, token)
    pricing = CartPricingService.call(cart: cart)
    totals = pricing[:totals]
    rules_data = CartRulesService.call(subtotal_new_byn: totals[:subtotal_new_byn])
    pricing_map = pricing[:items].index_by { |entry| entry[:sku] }
    cart_items = cart.cart_items.includes(:product)

    {
      cart: {
        token: token || cart.guest_token,
        expires_at: cart.expires_at.iso8601,
        items_count: cart_items.sum(:quantity),
        items: build_items(cart_items, pricing_map),
        totals: format_totals(totals),
        rules: format_rules(rules_data[:rules]),
        flags: format_flags(rules_data[:flags])
      }
    }
  end

  def build_items(cart_items, pricing_map)
    cart_items.map do |item|
      product = item.product
      available = product.present? && (product.quantity.nil? || product.quantity.positive?)
      issue_reason = issue_reason_for(product, available)
      similar = available || product.nil? ? [] : build_similar_products(product)
      pricing_line = pricing_map[item.product_sku] || {}

      {
        sku: item.product_sku,
        quantity: item.quantity,
        available: available,
        issue_reason: issue_reason,
        product: product_payload(product),
        pricing: pricing_payload(pricing_line),
        similar_products: similar
      }
    end
  end

  def pricing_payload(pricing_line)
    {
      unit_price_old_byn: format_byn(pricing_line[:unit_price_old_byn]),
      unit_price_new_byn: format_byn(pricing_line[:unit_price_new_byn]),
      unit_discount_byn: format_byn(pricing_line[:unit_discount_byn]),
      line_total_old_byn: format_byn(pricing_line[:line_total_old_byn]),
      line_total_new_byn: format_byn(pricing_line[:line_total_new_byn]),
      line_discount_byn: format_byn(pricing_line[:line_discount_byn]),
      promo_applied: pricing_line[:promo_applied] || false,
      promo_code: pricing_line[:promo_code]
    }
  end

  def product_payload(product)
    return nil unless product

    {
      sku: product.sku,
      name: product.name,
      price_byn: format_byn(product.price),
      quantity: product.quantity,
      category_id: product.category_id,
      collection: product.collection,
      images: {
        local_images: product.local_images || [],
        images: product.images || []
      }
    }
  end

  def build_similar_products(product)
    SimilarProductsService.for(product: product, limit: 8).map do |similar|
      {
        sku: similar.sku,
        name: similar.name,
        price_byn: format_byn(similar.price),
        quantity: similar.quantity,
        category_id: similar.category_id,
        collection: similar.collection,
        images: {
          local_images: similar.local_images || [],
          images: similar.images || []
        }
      }
    end
  end

  def issue_reason_for(product, available)
    return 'not_found' if product.nil?
    return 'unavailable' unless available

    nil
  end

  def format_totals(totals)
    {
      subtotal_old_byn: format_byn(totals[:subtotal_old_byn]),
      subtotal_new_byn: format_byn(totals[:subtotal_new_byn]),
      discount_total_byn: format_byn(totals[:discount_total_byn]),
      total_weight_kg: totals[:total_weight_kg]
    }
  end

  def format_rules(rules)
    {
      min_order_amount_byn: format_byn(rules[:min_order_amount_byn]),
      free_delivery_threshold_byn: format_byn(rules[:free_delivery_threshold_byn])
    }
  end

  def format_flags(flags)
    {
      checkout_allowed: flags[:checkout_allowed],
      min_order_missing_byn: format_byn(flags[:min_order_missing_byn]),
      free_delivery_eligible: flags[:free_delivery_eligible],
      free_delivery_missing_byn: format_byn(flags[:free_delivery_missing_byn])
    }
  end

  def format_byn(value)
    sprintf('%.2f', value.to_f)
  end
end
