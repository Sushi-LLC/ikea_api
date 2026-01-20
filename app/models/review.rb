class Review < ApplicationRecord
  PUBLISHED_STATUSES = %i[published].freeze

  belongs_to :user
  belongs_to :order, optional: true
  belongs_to :product, primary_key: :sku, foreign_key: :product_sku, optional: true

  has_many :review_helpful_votes, dependent: :destroy
  has_many_attached :photos

  enum status: {
    pending: 0,
    published: 1,
    rejected: 2,
    hidden: 3
  }

  validates :product_sku, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :body, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :user, presence: true
  validate :product_must_be_purchased_by_user

  before_validation :assign_order_for_review, on: :create
  before_save :set_published_at_if_needed

  after_create_commit :enqueue_review_created_job
  after_update_commit :handle_status_and_rating_changes
  after_destroy_commit :recalculate_product_rating

  scope :published_reviews, -> { published.where(excluded_from_rating: false) }

  def helpful_count
    review_helpful_votes.size
  end

  def photos_urls(host:)
    photos.map { |photo| Rails.application.routes.url_helpers.rails_blob_url(photo, host: host) }
  rescue ArgumentError
    photos.map { |photo| Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true) }
  end

  private

  def assign_order_for_review
    return if order_id.present? || product_sku.blank? || user.blank?

    matching_order = user.orders.purchased
                          .joins(:order_items)
                          .where(order_items: { product_sku: product_sku })
                          .order(purchased_at: :desc)
                          .first

    self.order = matching_order if matching_order
  end

  def product_must_be_purchased_by_user
    return if order.present? || product_sku.blank? || user.blank?

    errors.add(:product_sku, 'Отзыв можно оставить только на купленный товар')
  end

  def set_published_at_if_needed
    return unless status == 'published' && published_at.blank? && will_save_change_to_status?

    self.published_at = Time.current
  end

  def handle_status_and_rating_changes
    Crm::PushReviewPublishedJob.perform_later(self) if saved_change_to_status? && published?
    ProductRatingCalculator.recalculate!(product_sku) if saved_change_to_status? || saved_change_to_excluded_from_rating?
  end

  def recalculate_product_rating
    ProductRatingCalculator.recalculate!(product_sku) if product_sku.present?
  end

  def enqueue_review_created_job
    Crm::PushReviewCreatedJob.perform_later(self)
  end
end
