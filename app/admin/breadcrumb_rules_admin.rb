Trestle.resource(:breadcrumb_rules, model: BreadcrumbRule) do
  menu do
    item :breadcrumb_rules, icon: "fa fa-list", priority: 1, label: "Breadcrumb Rules", group: "SEO"
  end

  table do
    column :entity_type
    column :rule_type do |rule|
      rule.rule_type.humanize
    end
    column :active do |rule|
      status_tag(rule.active? ? "Да" : "Нет", rule.active? ? :success : :secondary)
    end
    column :created_at
    actions
  end

  form do |rule|
    static_field :hint, label: false do
      "build_tree: получает полную цепочку категорий (предки + актуальная категория)"
    end
    static_field :hint, label: false do
      "build_primary_category_only: только primary_category"
    end
    
    select :entity_type, BreadcrumbRule::ENTITY_TYPES.map { |entity| [entity.humanize, entity] }
    select :rule_type, BreadcrumbRule.rule_types.keys.map { |type| [type.humanize, type] }

    check_box :active
    # text_area :payload, rows: 3, label: "Payload (JSON)"
  end
end
