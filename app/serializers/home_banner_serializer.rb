class HomeBannerSerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :id, :section, :variant, :title, :subtitle, :position, :active, :created_at, :updated_at
  
  belongs_to :category, serializer: CategorySerializer, if: Proc.new { |record| record.category.present? }
  
  attribute :image_url do |banner, params|
    if banner.image.attached?
      base_url = params[:base_url] || ''
      if base_url.present?
        Rails.application.routes.url_helpers.rails_blob_url(banner.image, host: base_url)
      else
        Rails.application.routes.url_helpers.rails_blob_path(banner.image, only_path: true)
      end
    else
      nil
    end
  end
  
  attribute :link_url do |banner|
    if banner.category.present?
      banner.category.url || "/categories/#{banner.category.ikea_id}"
    else
      nil
    end
  end
end
