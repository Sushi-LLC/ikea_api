class ProductTitleTemplate < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
