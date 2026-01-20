class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product, primary_key: :sku, foreign_key: :product_sku, optional: true

  validates :product_sku, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
