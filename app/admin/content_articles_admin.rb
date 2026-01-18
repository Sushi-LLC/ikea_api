Trestle.resource(:content_articles, model: ContentArticle) do
  menu do
    item :content_articles, icon: "fa fa-newspaper", label: "Контент", group: "Content"
  end

  scopes do
    scope :all, default: true
    scope :tips_ideas, -> { ContentArticle.tips_ideas }
    scope :news, -> { ContentArticle.news }
    scope :published, -> { ContentArticle.visible }
  end

  table do
    column :content_type do |article|
      article.content_type.titleize
    end
    column :status
    column :title, link: true
    column :slug
    column :pinned do |article|
      article.pinned? ? "Да" : "Нет"
    end
    column :published_at
    actions
  end

  form do |article|
    tab :general do
      row do
        col(sm: 6) { select :content_type, ContentArticle.content_types.keys.map { |key| [key.humanize, key] } }
        col(sm: 6) { select :status, ContentArticle.statuses.keys.map { |key| [key.humanize, key] } }
      end
      row do
        col(sm: 12) { text_field :title, required: true }
      end
      row do
        col(sm: 12) { text_field :slug, help: "Если не заполнено — будет сгенерировано автоматически" }
      end
      row do
        col(sm: 12) { text_area :excerpt, rows: 3, help: "Короткое описание для плитки" }
      end
      row do
        col(sm: 12) do
          text_area :body_blocks_json, rows: 6, help: "JSON-массив блоков статьи"
        end
      end
      row do
        col(sm: 12) do
          text_area :tile_blocks_json, rows: 4, help: "Настройки плитки (JSON-массив)"
        end
      end
    end

    tab :filters do
      row do
        col(sm: 4) do
          text_area :components_input, rows: 3, help: "Одна строка = один компонент"
        end
        col(sm: 4) do
          text_area :projects_input, rows: 3, help: "Одна строка = один проект"
        end
        col(sm: 4) do
          text_area :tags_input, rows: 3, help: "Одна строка = один тег"
        end
      end
    end

    tab :links do
      row do
        col(sm: 6) do
          text_area :product_skus_input, rows: 4, help: "SKU товаров (штроки, разделенные переносами)"
        end
        col(sm: 6) do
          text_area :category_ids_input, rows: 4, help: "Категории (ikea_id), одна строка = одна категория"
        end
      end
    end

    tab :publication do
      row do
        col(sm: 6) do
          check_box :pinned, label: "Закрепить сверху"
        end
        col(sm: 6) do
          number_field :pinned_position, label: "Порядок закрепления"
        end
      end
      row do
        col(sm: 6) { datetime_field :published_at }
        col(sm: 6) { check_box :active }
      end
    end
  end
end
