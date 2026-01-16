Trestle.resource(:popular_search_queries, model: PopularSearchQuery) do
  menu do
    item :popular_search_queries, icon: "fa fa-search", priority: 3, label: "Популярные запросы", group: "Catalog"
  end

  table do
    column :query
    column :weight do |record|
      number_with_precision(record.weight || 0, precision: 0)
    end
    column :active do |record|
      status_tag(record.active ? 'Активен' : 'Отключен', record.active ? :success : :secondary)
    end
    column :created_at, align: :center
    column :updated_at, align: :center
    actions
  end

  form do |record|
    text_field :query
    number_field :weight
    check_box :active
  end
end
