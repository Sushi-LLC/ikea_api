class PromoCode < ApplicationRecord
  has_many :promo_code_products, dependent: :destroy

  enum discount_type: { percent: 0, fixed_byn: 1 }

  validates :code, presence: true, uniqueness: true
  validates :discount_value, presence: true, numericality: { greater_than: 0 }

  before_validation :normalize_code

  def active_now?(time = Time.current)
    return false unless active
    return false if starts_at.present? && starts_at > time
    return false if ends_at.present? && ends_at < time

    true
  end

  def expired?(time = Time.current)
    ends_at.present? && ends_at < time
  end

  def applies_to_sku?(sku)
    return true unless promo_code_products.exists?

    promo_code_products.where(product_sku: sku).exists?
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end
end
