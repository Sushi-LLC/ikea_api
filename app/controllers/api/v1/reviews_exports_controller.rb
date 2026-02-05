require 'csv'

module Api
  module V1
    class ReviewsExportsController < ApplicationController
      before_action :authenticate_user
      before_action :require_admin

      def index
        reviews = Review.includes(photos_attachments: :blob).order(created_at: :desc)

        respond_to do |format|
          format.csv { send_data build_csv(reviews), filename: export_filename, type: 'text/csv' }
          format.json { render json: build_json(reviews) }
        end
      end

      private

      def require_admin
        render json: { error: 'Недостаточно прав' }, status: :forbidden unless current_user&.admin?
      end

      def export_filename
        "reviews-export-#{Time.current.strftime('%Y%m%d')}.csv"
      end

      def build_csv(reviews)
        CSV.generate(headers: true) do |csv|
          csv << csv_headers
          reviews.each do |review|
            csv << [
              review.id,
              review.product_sku,
              review.user_id,
              review.rating,
              review.body,
              review.status,
              review.helpful_count,
              review.excluded_from_rating,
              review.pinned,
              review.created_at,
              review.published_at,
              review.photos_urls(host: request.base_url).join(';')
            ]
          end
        end
      end

      def build_json(reviews)
        reviews.map do |review|
          {
            review_id: review.id,
            product_sku: review.product_sku,
            user_id: review.user_id,
            rating: review.rating,
            body: review.body,
            status: review.status,
            helpful_count: review.helpful_count,
            excluded_from_rating: review.excluded_from_rating,
            pinned: review.pinned,
            created_at: review.created_at,
            published_at: review.published_at,
            photos_urls: review.photos_urls(host: request.base_url)
          }
        end
      end

  def csv_headers
    %w[
      review_id product_sku user_id rating body status helpful_count
      excluded_from_rating pinned created_at published_at photos_urls
    ]
  end
    end
  end
end
