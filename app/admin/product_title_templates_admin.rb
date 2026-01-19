Trestle.resource(:product_title_templates, model: ProductTitleTemplate) do
  menu do
    item :product_title_templates, icon: "fa fa-heading", label: "SEO шаблоны", group: "Catalog"
  end

  table do
    column :key
    column :active do |record|
      status_tag(record.active ? "Активен" : "Отключен", record.active ? :success : :secondary)
    end
    column :template_string do |record|
      simple_format(record.template_string.to_s, {}, wrapper_tag: "div")
    end
    column :created_at, align: :center
    column :updated_at, align: :center
    actions
  end

  form do |template|
    text_field :key, required: true
    text_area :template_string,
              label: "Шаблон",
              rows: 4,
              help: "Поддерживаются {{name}}, {{sku}}, {{collection}}, {{category}}, {{color}}, {{size}}"
    check_box :active, label: "Активен"
  end
end
