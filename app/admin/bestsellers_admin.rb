Trestle.resource(:bestsellers, model: Product) do
  scope :all, -> { Product.bestsellers }, default: true
  menu do
    item :bestsellers, icon: "fa fa-star", label: "Хиты продаж", priority: 4, group: "Catalog"
  end

  table do
    column :sku, link: true
    column :name
    column :name_ru
    column :category do |product|
      product.category&.name || 'Без категории'
    end
    column :price do |product|
      number_to_currency(product.price, unit: 'Zl', format: '%n %u')
    end
    column :quantity
    column :is_bestseller do |product|
      status_tag(product.is_bestseller? ? 'Да' : 'Нет', 
                 product.is_bestseller? ? :success : :secondary)
    end
    column :created_at, align: :center
    actions
  end

  form do |product|
    check_box :is_bestseller
  end
end

