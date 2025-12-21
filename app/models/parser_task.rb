class ParserTask < ApplicationRecord
  TASK_TYPES = %w[categories products bestsellers popular_categories category_images product_images].freeze
  STATUSES = %w[pending running completed failed].freeze

  validates :task_type, presence: true, inclusion: { in: TASK_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :by_type, ->(type) { where(task_type: type) }

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def mark_as_running!
    update!(
      status: 'running',
      started_at: Time.current,
      error_message: nil
    )
  end

  def mark_as_completed!(stats = {})
    update!(
      status: 'completed',
      completed_at: Time.current,
      processed: stats[:processed] || 0,
      created: stats[:created] || 0,
      updated: stats[:updated] || 0,
      error_count: stats[:errors] || 0
    )
  end

  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error_message
    )
  end

  def increment_processed!
    increment!(:processed)
  end

  def increment_created!
    increment!(:created)
  end

  def increment_updated!
    increment!(:updated)
  end

  def increment_errors!
    increment!(:error_count)
  end
end


