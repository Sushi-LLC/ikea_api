class HomeBanner < ApplicationRecord
  require 'mini_magick'
  
  # Enums
  enum section: {
    main: 0,
    secondary: 1
  }
  
  enum variant: {
    main_1500x516: 0,
    main_572x594: 1,
    secondary_1500x256: 2,
    secondary_742x256: 3
  }
  
  # Associations
  belongs_to :category, foreign_key: :category_id, primary_key: :ikea_id, optional: true
  has_one_attached :image
  
  # Callbacks
  before_validation :normalize_category_id
  # after_commit :validate_image_dimensions_after_save, on: [:create, :update], if: -> { image.attached? }
  
  # Validations
  validates :section, presence: true
  validates :variant, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validate :validate_image_presence
  validate :validate_image_content_type
  # validate :validate_variant_matches_section
  
  # Scopes
  scope :by_position, -> { order(position: :asc) }
  scope :active, -> { where(active: true) }
  
  # Instance methods
  def image_url
    return nil unless image.attached?
    Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
  end
  
  def expected_dimensions
    case variant
    when 'main_1500x516'
      [1500, 516]
    when 'main_572x594'
      [572, 594]
    when 'secondary_1500x256'
      [1500, 256]
    when 'secondary_742x256'
      [742, 256]
    else
      nil
    end
  end
  
  private
  
  def validate_image_presence
    errors.add(:image, 'must be present') unless image.attached?
  end
  
  def validate_image_content_type
    return unless image.attached?
    
    allowed_types = %w[image/webp image/avif image/png image/jpeg]
    content_type = image.content_type
    
    unless allowed_types.include?(content_type)
      errors.add(:image, 'must be a WebP, AVIF, PNG, or JPEG image')
    end
  end
  
  def validate_image_dimensions_after_save
    return unless image.attached?
    return unless expected_dimensions
    
    begin
      # Small delay to ensure file is available (especially for new uploads)
      sleep(0.2) if Rails.env.test? || Rails.env.development?
      
      # Download the image to temp file for processing
      image.blob.open do |temp_file|
        img = MiniMagick::Image.open(temp_file.path)
        
        expected_width, expected_height = expected_dimensions
        
        unless img.width == expected_width && img.height == expected_height
          # Mark banner as inactive if dimensions don't match
          update_column(:active, false) unless active == false
          # Log error
          Rails.logger.warn "HomeBanner ##{id}: Image dimensions #{img.width}x#{img.height} don't match expected #{expected_width}x#{expected_height} for variant #{variant}. Banner deactivated."
        end
      end
    rescue MiniMagick::Error => e
      Rails.logger.error "Error validating image dimensions for HomeBanner ##{id}: #{e.message}"
      update_column(:active, false) unless active == false
    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.error "File not found during validation for HomeBanner ##{id}: #{e.message}"
      # Retry after delay (max 2 retries)
      if (@dimension_validation_retries ||= 0) < 2
        @dimension_validation_retries += 1
        sleep(0.5)
        validate_image_dimensions_after_save
      end
    rescue => e
      Rails.logger.error "Unexpected error validating image dimensions for HomeBanner ##{id}: #{e.message}"
    end
  end
  
  def normalize_category_id
    self.category_id = nil if category_id.blank?
  end
  
  def validate_variant_matches_section
    return unless section.present? && variant.present?
    
    case section
    when 'main'
      unless %w[main_1500x516 main_572x594].include?(variant)
        errors.add(:variant, 'must be main_1500x516 or main_572x594 for main section')
      end
    when 'secondary'
      unless %w[secondary_1500x256 secondary_742x256].include?(variant)
        errors.add(:variant, 'must be secondary_1500x256 or secondary_742x256 for secondary section')
      end
    end
  end
end
