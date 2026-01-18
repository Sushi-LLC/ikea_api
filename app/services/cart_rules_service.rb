class CartRulesService
  DEFAULTS = {
    min_order_amount_byn: 150.0,
    free_delivery_threshold_byn: 0.0
  }.freeze

  def self.call(subtotal_new_byn:)
    subtotal = subtotal_new_byn || 0
    min_order = fetch_setting('min_order_amount_byn', DEFAULTS[:min_order_amount_byn])
    free_delivery = fetch_setting('free_delivery_threshold_byn', DEFAULTS[:free_delivery_threshold_byn])

    checkout_allowed = subtotal >= min_order
    min_order_missing = [min_order - subtotal, 0].max
    free_delivery_eligible = subtotal >= free_delivery
    free_delivery_missing = [free_delivery - subtotal, 0].max

    {
      rules: {
        min_order_amount_byn: min_order,
        free_delivery_threshold_byn: free_delivery
      },
      flags: {
        checkout_allowed: checkout_allowed,
        min_order_missing_byn: min_order_missing,
        free_delivery_eligible: free_delivery_eligible,
        free_delivery_missing_byn: free_delivery_missing
      }
    }
  end

  def self.fetch_setting(key, fallback)
    value = CalculatorSetting.get(key)
    value.nil? ? fallback : value
  end
  private_class_method :fetch_setting
end
