Trestle.resource(:products, model: Product) do
  menu do
    item :products, icon: "fa fa-cube", priority: 3
  end

  scopes do
    scope :all, default: true
    scope :bestsellers, -> { Product.bestsellers }
    scope :popular, -> { Product.popular }
  end

  table do
    column :sku, link: true
    column :name
    column :name_ru
    column :category do |product|
      product.category&.name || 'Без категории'
    end
    column :price do |product|
      number_to_currency(product.price, unit: 'BYN', format: '%n %u')
    end
    column :quantity
    column :is_bestseller do |product|
      status_tag(product.is_bestseller? ? 'Да' : 'Нет', 
                 product.is_bestseller? ? :success : :secondary)
    end
    column :is_popular do |product|
      status_tag(product.is_popular? ? 'Да' : 'Нет', 
                 product.is_popular? ? :success : :secondary)
    end
    column :created_at, align: :center
    actions
  end

  controller do
    def show
      @product = admin.find_instance(params)
      render "trestle/products/show"
    end
  end

  form do |product|
    tab :basic, label: "Основная информация" do
      text_field :sku
      text_field :unique_id
      text_field :item_no
      text_field :url
      text_field :name
      text_field :name_ru
      text_field :collection
      select :category_id, Category.all.map { |c| [c.name, c.ikea_id] }, label: "Категория"
    end

    tab :pricing, label: "Цена и наличие" do
      number_field :price
      number_field :quantity
      text_field :home_delivery
    end

    tab :specs, label: "Характеристики" do
      number_field :weight
      number_field :net_weight
      number_field :package_volume
      text_field :package_dimensions
      text_field :dimensions
      check_box :is_parcel
    end

    tab :flags, label: "Флаги" do
      check_box :is_bestseller
      check_box :is_popular
      check_box :translated
    end

    tab :delivery, label: "Доставка" do
      text_field :delivery_type
      text_field :delivery_name
      number_field :delivery_cost
      text_field :delivery_reason
    end
  end

end

