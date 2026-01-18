class ContentArticleCategory < ApplicationRecord
  belongs_to :content_article
  belongs_to :category, primary_key: :ikea_id, foreign_key: :category_id, optional: true

  validates :category_id, presence: true
  validates :content_article, presence: true
end
