Trestle.resource(:search_query_logs, model: SearchQueryLog, readonly: true) do
  menu do
    item :search_query_logs, icon: "fa fa-history", priority: 5, label: "Логи поиска", group: "Analytics"
  end

  table do
    column :created_at, align: :center
    column :customer do |record|
      record.customer&.username || 'Гость'
    end
    column :query
    column :results_count
    column :clicked_product_sku
    actions
  end

  controller do
    def collection
      super.reorder(created_at: :desc)
    end
  end
end
