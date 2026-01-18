class ContentArticleProduct < ApplicationRecord
  enum source: { manual: 0, auto: 1 }

  belongs_to :content_article
  belongs_to :product, primary_key: :sku, foreign_key: :product_sku, optional: true

  validates :product_sku, presence: true
  validates :content_article, presence: true
end
