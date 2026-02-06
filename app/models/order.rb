class Order < ApplicationRecord
  belongs_to :user
  belongs_to :promo_code, optional: true
  has_many :order_items, dependent: :destroy

  enum status: {
    processing: 0,
    awaiting_payment: 1,
    created: 2,
    received_poland: 3,
    picking: 4,
    customs_poland: 5,
    customs_belarus: 6,
    in_delivery_pvz: 7,
    arrived_pvz: 8,
    completed: 9,
    cancelled: 10
  }

  PURCHASED_STATUSES = %w[arrived_pvz completed].freeze

  scope :purchased, -> { where(status: PURCHASED_STATUSES) }

  before_save :set_purchased_at

  def purchased?
    status.in?(PURCHASED_STATUSES)
  end

  private

  def set_purchased_at
    return unless transitioning_to_purchased?

    self.purchased_at ||= Time.current
  end

  def transitioning_to_purchased?
    will_save_change_to_status? && status.in?(PURCHASED_STATUSES)
  end
end
