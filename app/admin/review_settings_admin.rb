Trestle.resource(:review_settings, model: ReviewSetting) do
  menu do
    item :review_settings, icon: "fa fa-cog", label: "Настройки рейтинга", group: "Content"
  end

  routes do
    post :recalculate, on: :collection
  end

  controller do
    def index
      redirect_to edit_review_settings_admin_path(ReviewSetting.instance)
    end

    def show
      redirect_to edit_review_settings_admin_path(ReviewSetting.instance)
    end

    def edit
      @review_setting = ReviewSetting.instance
      super
    end

    def update
      @review_setting = ReviewSetting.instance
      super
    end

    def recalculate
      ReviewSetting.instance
      Product.find_each { |product| ProductRatingCalculator.recalculate!(product.sku) }
      redirect_to admin.edit_review_setting_path(ReviewSetting.instance), notice: "Рейтинги пересчитаны"
    end
  end

  form do |setting|
    row do
      col(sm: 12) do
        content_tag :p do
          "Рейтинг товаров пересчитывается как средневзвешенное значение: базовый вес отзыва плюс вес за каждый голос «полезно», умноженный на коэффициент. Изменение этих параметров влияет на `rating_weighted` и может изменить сортировку по рейтингу."
        end
      end
    end
    row do
      col(sm: 6) do
        number_field :helpful_weight_factor, step: 0.01, label: "Вес полезности"
      end
      col(sm: 6) do
        number_field :base_weight, step: 0.01, label: "Базовый вес"
      end
    end
    row do
      col(sm: 12) do
        concat button_to "Пересчитать рейтинги вручную", recalculate_review_settings_admin_index_path, method: :post, class: "btn btn-sm btn-outline-primary"
      end
    end
  end

  params do |params|
    params.require(:review_setting).permit(:helpful_weight_factor, :base_weight)
  end
end
