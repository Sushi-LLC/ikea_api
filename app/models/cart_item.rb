class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product, foreign_key: :product_sku, primary_key: :sku, optional: true

  validates :product_sku, presence: true
  validates :quantity, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 999
  }

  def line_total_byn
    (product&.price || 0) * quantity
  end
end
