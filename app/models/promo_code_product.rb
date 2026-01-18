class PromoCodeProduct < ApplicationRecord
  belongs_to :promo_code

  validates :product_sku, presence: true
end
