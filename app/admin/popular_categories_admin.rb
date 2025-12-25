Trestle.resource(:popular_categories, model: Category) do
  scope :all, -> { Category.popular }, default: true
  menu do
    item :popular_categories, icon: "fa fa-fire", label: "Популярные категории", priority: 3, group: "Catalog"
  end

  table do
    column :ikea_id
    column :name, link: true
    column :translated_name
    column :is_popular do |category|
      status_tag(category.is_popular? ? 'Да' : 'Нет', 
                 category.is_popular? ? :success : :secondary)
    end
    column :is_deleted do |category|
      status_tag(category.is_deleted? ? 'Удалена' : 'Активна', 
                 category.is_deleted? ? :danger : :success)
    end
    column :products_count do |category|
      category.products.count
    end
    column :created_at, align: :center
    actions
  end

  form do |category|
    check_box :is_popular
  end
end

