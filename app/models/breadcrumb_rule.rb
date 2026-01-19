class BreadcrumbRule < ApplicationRecord
  ENTITY_TYPES = %w[product].freeze

  enum rule_type: {
    by_primary_category_tree: 0,
    by_primary_category_only: 1
  }

  validates :entity_type, presence: true, inclusion: { in: ENTITY_TYPES }
  validates :rule_type, presence: true
  validates :active, inclusion: { in: [true, false] }

  scope :active, -> { where(active: true) }

  validate :single_active_rule_per_entity_type

  def self.active_for(entity_type)
    active.find_by(entity_type: entity_type)
  end

  private

  def single_active_rule_per_entity_type
    return unless active?

    existing = BreadcrumbRule.where(entity_type: entity_type, active: true)
    existing = existing.where.not(id: id) if persisted?
    errors.add(:active, "already exists for #{entity_type}") if existing.exists?
  end
end
