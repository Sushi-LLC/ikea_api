class Category < ApplicationRecord
  self.primary_key = 'ikea_id'
  
  validates :ikea_id, presence: true, uniqueness: true
  validates :name, presence: true
  
  has_many :products, foreign_key: :category_id, primary_key: :ikea_id
  
  serialize :parent_ids, coder: JSON
  
  scope :popular, -> { where(is_popular: true) }
  scope :active, -> { where(is_deleted: false) }
end
