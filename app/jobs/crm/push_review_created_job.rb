module Crm
  class PushReviewCreatedJob < ApplicationJob
    queue_as :default

    def perform(review)
      payload = {
        review_id: review.id,
        user_id: review.user_id,
        product_sku: review.product_sku,
        rating: review.rating,
        status: review.status,
        created_at: review.created_at
      }

      Rails.logger.info("[CRM] Review created: #{payload}")
    end
  end
end
