Trestle.resource(:categories, model: Category) do
  menu do
    item :categories, icon: "fa fa-folder", priority: 1, label: "Категории", group: "Catalog"
  end

  scopes do
    scope :all, default: true
    scope :top_level, -> { Category.top_level }, label: "Верхнеуровневые"
    scope :popular, -> { Category.popular }, label: "Популярные"
    scope :active, -> { Category.active }, label: "Активные"
  end

  table do
    column :ikea_id
    column :translated_name 
    column :name, link: true
    column :is_popular do |category|
      status_tag(category.is_popular? ? 'Да' : 'Нет', 
                 category.is_popular? ? :success : :secondary)
    end
    column :is_deleted do |category|
      status_tag(category.is_deleted? ? 'Удалена' : 'Активна', 
                 category.is_deleted? ? :danger : :success)
    end
    column :products_count, label: "Продуктов" do |category|
      category.products.count
    end
    column :children_count, label: "Дочерних категорий" do |category|
      category.children_count
    end
    column :created_at, align: :center
    actions
  end

  controller do
    def show
      @category = admin.find_instance(params)
      render "trestle/categories/show"
    end
  end

  form do |category|
    text_field :ikea_id
    text_field :name
    text_field :translated_name
    check_box :is_popular
    check_box :is_deleted
    text_area :parent_ids, label: "Parent IDs (JSON)"
  end

end

