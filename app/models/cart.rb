class Cart < ApplicationRecord
  has_many :cart_items, dependent: :destroy
  belongs_to :promo_code, optional: true
  belongs_to :user, optional: true

  validates :guest_token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :ensure_defaults, on: :create

  def touch_expiration!
    update!(expires_at: 1.year.from_now)
  end

  def expired?
    expires_at < Time.current
  end

  private

  def ensure_defaults
    self.guest_token ||= SecureRandom.hex(24)
    self.expires_at ||= 1.year.from_now
  end
end
