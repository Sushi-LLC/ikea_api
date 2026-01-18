Trestle.resource(:calculator_settings, model: CalculatorSetting) do
  TRACKED_KEYS = %w[min_order_amount_byn free_delivery_threshold_byn] unless defined?(TRACKED_KEYS)

  menu do
    item :calculator_settings, icon: "fa fa-cogs", label: "Правила корзины", group: "Marketing"
  end

  collection do
    CalculatorSetting.where(key: TRACKED_KEYS)
  end

  table do
    column :key, link: true
    column :value
    column :setting_type
    column :updated_at
    actions
  end

  form do |setting|
    select :key, TRACKED_KEYS.map { |key| [key.humanize, key] }, label: "Ключ"
    hidden_field :setting_type, value: 'decimal'
    number_field :value, step: 0.01
    text_field :description
  end
end
