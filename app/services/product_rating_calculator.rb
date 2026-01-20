class ProductRatingCalculator
  class << self
    def recalculate!(product_sku)
      return unless product_sku.present?

      product = Product.find_by(sku: product_sku)
      return unless product

      reviews = Review.published_reviews.where(product_sku: product_sku)
      aggregate_and_persist(product, reviews)
    end

    private

    def aggregate_and_persist(product, reviews)
      if reviews.empty?
        return product.update!(
          rating_avg: 0,
          rating_weighted: 0,
          rating_count: 0,
          rating_updated_at: Time.current
        )
      end

      helpful_counts = ReviewHelpfulVote.where(review_id: reviews.select(:id)).group(:review_id).count
      settings = ReviewSetting.instance
      base_weight = settings.base_weight.to_d
      helpful_weight_factor = settings.helpful_weight_factor.to_d

      total_weight = 0
      weighted_sum = 0

      reviews.each do |review|
        helpful = helpful_counts[review.id] || 0
        weight = base_weight + helpful * helpful_weight_factor
        total_weight += weight
        weighted_sum += review.rating * weight
      end

      weighted_score = total_weight.positive? ? weighted_sum / total_weight : 0
      product.update!(
        rating_avg: reviews.average(:rating)&.to_d&.round(2) || 0,
        rating_weighted: weighted_score.round(2),
        rating_count: reviews.count,
        rating_updated_at: Time.current
      )
    end
  end
end
