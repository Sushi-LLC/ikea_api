class PopularSearchQuery < ApplicationRecord
  validates :query, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(weight: :desc, updated_at: :desc) }
  scope :matching, ->(term) {
    term.present? ? where('query ILIKE ?', "#{term}%") : all
  }
end
