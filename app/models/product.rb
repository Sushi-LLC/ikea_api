class Product < ApplicationRecord
  # Валидации
  validates :sku, presence: true, uniqueness: true
  validates :name, presence: true
  
  # Ассоциации
  # Старая связь (для обратной совместимости, будет удалена после миграции)
  belongs_to :category, foreign_key: :category_id, primary_key: :ikea_id, optional: true
  
  # Новая связь many-to-many
  has_many :category_products, dependent: :destroy
  has_many :categories, through: :category_products, source: :category
  
  def primary_category
    category || categories.order(:name).first
  end

  has_many :product_filter_values
  has_many :filter_values, through: :product_filter_values
  
  # Scopes
  scope :bestsellers, -> { where(is_bestseller: true) }
  scope :popular, -> { where(is_popular: true) }
  scope :with_category, -> { where.not(category_id: nil) }
  scope :by_rating, -> { order(rating_weighted: :desc, rating_count: :desc) }
  
  # Сериализация массивов
  serialize :variants, coder: JSON
  serialize :related_products, coder: JSON
  serialize :set_items, coder: JSON
  serialize :bundle_items, coder: JSON
  serialize :images, coder: JSON
  serialize :local_images, coder: JSON
  serialize :videos, coder: JSON
  serialize :manuals, coder: JSON
  serialize :features, coder: JSON
  serialize :assembly_documents, coder: JSON
  
  # Callbacks
  before_save :calculate_delivery, if: :weight_changed?
  
  private
  
  def calculate_delivery
    # Логика расчета доставки
    # Аналогично deliveryService.js
  end
end
