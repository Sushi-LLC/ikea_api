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
      ContentArticle.human_attribute_name("content_type.#{article.content_type}")
    end
    
    column :status do |article|
      ContentArticle.human_attribute_name("status.#{article.status}")
    end
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
        col(sm: 6) do
          select :content_type,
                 ContentArticle.content_types.keys.map { |key| [ContentArticle.human_attribute_name("content_type.#{key}"), key] },
                 label: "Тип контента"
        end
        
        col(sm: 6) do
          select :status,
                 ContentArticle.statuses.keys.map { |key| [ContentArticle.human_attribute_name("status.#{key}"), key] },
                 label: "Статус"
        end
      end
      row do
        col(sm: 12) { text_field :title, required: true, label: "Заголовок" }
      end
      row do
        col(sm: 12) { text_field :slug, label: "Slug", hint: "Если не заполнено — будет сгенерировано автоматически" }
      end
      row do
        col(sm: 12) { text_area :excerpt, rows: 3, label: "Короткое описание" }
      end
      row do
        col(sm: 12) do
          render "trestle/content_articles/body_block_builder", article: article
        end
      end
      row do
        col(sm: 12) do
          value = (article.serialized_body_blocks.presence || []).dup
          concat content_tag(:label, "JSON страницы", class: "form-label")
          concat text_area_tag(
            "page_rendered_blocks",
            JSON.pretty_generate(value),
            rows: 10,
            readonly: true,
            class: "form-control"
          )
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

  params do |params|
    params.require(:content_article).permit(
      :content_type,
      :status,
      :title,
      :slug,
      :excerpt,
      :body_blocks_json,
      :tile_blocks_json,
      :components_input,
      :projects_input,
      :tags_input,
      :product_skus_input,
      :category_ids_input,
      :pinned,
      :pinned_position,
      :published_at,
      :active
    )
  end
end
