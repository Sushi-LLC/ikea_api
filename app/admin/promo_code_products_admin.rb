Trestle.resource(:promo_code_products, model: PromoCodeProduct) do
  menu do
    item :promo_code_products, icon: "fa fa-link", label: "Промо-товары", group: "Marketing"
  end

  table do
    column :promo_code do |record|
      record.promo_code&.code
    end
    column :product_sku
    column :created_at
    actions
  end

  form do |promo_code_product|
    select :promo_code_id, PromoCode.all.map { |promo| [promo.code, promo.id] }, label: "Промокод"
    text_field :product_sku
  end
end
