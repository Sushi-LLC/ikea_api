class SearchQueryLog < ApplicationRecord
  belongs_to :customer, class_name: 'User', optional: true

  validates :query, presence: true
end
