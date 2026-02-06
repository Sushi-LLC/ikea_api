class User < ApplicationRecord
  include Trestle::Auth::ModelMethods
  include Trestle::Auth::ModelMethods::Rememberable
  
  has_secure_password
  
  validates :username, presence: true, uniqueness: true
  validates :email, uniqueness: true, allow_nil: true
  validates :role, inclusion: { in: %w[user admin manager] }
  
  scope :active, -> { where(is_active: true) }

  has_many :orders, dependent: :nullify
  has_many :reviews, dependent: :nullify
  has_one :cart, dependent: :destroy
  
  def admin?
    role == 'admin'
  end
  
  def manager?
    role == 'manager'
  end
  
  # Методы для Trestle Auth
  def first_name
    username.split(' ').first || username
  end
  
  def last_name
    username.split(' ').last || ''
  end
end
