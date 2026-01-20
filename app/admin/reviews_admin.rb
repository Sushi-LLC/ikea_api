Trestle.resource(:reviews, model: Review) do
  menu do
    item :reviews, icon: "fa fa-star", label: "Отзывы", group: "Content"
  end

  scopes do
    scope :all, default: true
    scope :pending, -> { Review.pending }
    scope :published, -> { Review.published }
    scope :rejected, -> { Review.rejected }
    scope :hidden, -> { Review.hidden }
  end

  table do
    column :id, link: true
    column :product_sku
    column :user do |review|
      review.user&.username || review.user_id
    end
    column :rating
    column :status do |review|
      status_tag(review.status, review.status == 'published' ? :success : :secondary)
    end
    column :helpful_count
    column "Фото" do |review|
      "#{review.photos.count} шт."
    end
    column :pinned do |review|
      status_tag(review.pinned? ? 'Да' : 'Нет',
                 review.pinned? ? :success : :secondary)
    end
    column :excluded_from_rating do |review|
      status_tag(review.excluded_from_rating? ? 'Да' : 'Нет',
                 review.excluded_from_rating? ? :warning : :secondary)
    end
    column :created_at
    actions
  end

  form do |review|
    row do
      col(sm: 4) { number_field :rating }
      col(sm: 4) do
        select :status,
               Review.statuses.keys.map { |status| [status.humanize, status] },
               label: "Статус"
      end
      col(sm: 4) { check_box :pinned }
    end

    row do
      col(sm: 6) { check_box :excluded_from_rating, label: "Исключить из рейтинга" }
      col(sm: 6) { text_field :product_sku, disabled: true, hint: "SKU товара" }
    end

    row do
      col(sm: 12) { text_area :body, rows: 4 }
    end

    row do
      col(sm: 12) { text_area :admin_note, rows: 3, label: "Примечание модератора" }
    end

    if review.photos.attached?
      row do
        col(sm: 12) do
          review.photos.each do |photo|
            concat(
              link_to(
                photo.filename.to_s,
                Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true)
              )
            )
            concat(tag(:br))
          end
        end
      end
    end

    row do
      col(sm: 12) do
        file_field :photos, multiple: true
      end
    end
  end

  params do |params|
    params.require(:review).permit(
      :rating,
      :status,
      :body,
      :admin_note,
      :pinned,
      :excluded_from_rating,
      photos: []
    )
  end
end
