module Api
  module V1
    class ReviewsController < ApplicationController
      before_action :authenticate_user
      before_action :set_user_review, only: [:update, :destroy]
      before_action :set_public_review, only: [:helpful, :remove_helpful]
      before_action :find_product, only: [:create]

      def create
        review = current_user.reviews.new(review_create_params.merge(product_sku: @product.sku))
        attach_photos(review, params.dig(:review, :photos))

        if review.save
          render json: ReviewSerializer.new(review, params: serializer_params), status: :created
        else
          render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        return render json: { error: 'Редактирование отзыва после модерации недоступно' }, status: :unprocessable_entity unless @review.pending?

        if @review.update(review_update_params)
          attach_photos(@review, params.dig(:review, :photos))
          render json: ReviewSerializer.new(@review.reload, params: serializer_params)
        else
          render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        if @review.pending?
          @review.destroy!
        else
          @review.update!(status: :hidden, excluded_from_rating: true)
        end

        head :no_content
      end

      def helpful
        vote = @review.review_helpful_votes.find_or_initialize_by(user: current_user)
        vote.save if vote.new_record?

        render json: { helpful_count: @review.reload.helpful_count }
      end

      def remove_helpful
        vote = @review.review_helpful_votes.find_by(user: current_user)
        vote&.destroy

        head :no_content
      end

      private

      def set_user_review
        @review = current_user.reviews.find(params[:id])
      end

      def set_public_review
        @review = Review.published.find(params[:id])
      end

      def find_product
        @product = Product.find_by!(sku: params[:product_sku])
      end

      def review_create_params
        params.require(:review).permit(:rating, :body)
      end

      def review_update_params
        params.require(:review).permit(:rating, :body)
      end

      def attach_photos(record, attachments)
        return unless attachments

        record.photos.attach(attachments)
      end

      def serializer_params
        { host: request.base_url }
      end
    end
  end
end
