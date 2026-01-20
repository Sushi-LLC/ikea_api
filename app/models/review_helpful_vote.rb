class ReviewHelpfulVote < ApplicationRecord
  belongs_to :review
  belongs_to :user

  after_create_commit :recalculate_product_rating
  after_destroy_commit :recalculate_product_rating

  private

  def recalculate_product_rating
    ProductRatingCalculator.recalculate!(review.product_sku) if review.product_sku.present?
  end
end
