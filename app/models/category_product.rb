class CategoryProduct < ApplicationRecord
  belongs_to :product
  belongs_to :category, foreign_key: :category_id, primary_key: :ikea_id
  
  validates :product_id, presence: true
  validates :category_id, presence: true
  validates :product_id, uniqueness: { scope: :category_id, message: "уже связан с этой категорией" }
end
