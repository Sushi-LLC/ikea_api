module Crm
  class PushReviewPublishedJob < ApplicationJob
    queue_as :default

    def perform(review)
      payload = {
        review_id: review.id,
        product_sku: review.product_sku,
        rating: review.rating,
        published_at: review.published_at,
        helpful_count: review.helpful_count
      }

      Rails.logger.info("[CRM] Review published: #{payload}")
    end
  end
end
