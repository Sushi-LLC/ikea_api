Trestle.resource(:promo_codes, model: PromoCode) do
  menu do
    item :promo_codes, icon: "fa fa-percent", label: "Промокоды", group: "Marketing"
  end

  table do
    column :code, link: true
    column :name
    column :discount_type
    column :discount_value do |promo_code|
      number_to_currency(promo_code.discount_value, unit: 'BYN', format: '%n %u')
    end
    column :active do |promo_code|
      status_tag(promo_code.active? ? 'Да' : 'Нет', promo_code.active? ? :success : :secondary)
    end
    column :starts_at
    column :ends_at
    column :updated_at
    actions
  end

  form do |promo_code|
    text_field :code
    text_field :name
    select :discount_type, PromoCode.discount_types.keys.map { |type| [type.humanize, type] }
    number_field :discount_value, step: 0.01
    check_box :active
    datetime_field :starts_at
    datetime_field :ends_at
  end
end
