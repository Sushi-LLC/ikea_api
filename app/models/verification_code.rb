class VerificationCode < ApplicationRecord
  validates :phone, presence: true
  validates :code, presence: true
  validates :expires_at, presence: true

  scope :valid_code, ->(phone, code) { 
    where(phone: phone, code: code)
    .where('expires_at > ?', Time.current) 
  }

  def self.generate_code
    rand(1000..9999).to_s
  end
end
