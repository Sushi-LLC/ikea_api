class CronSchedule < ApplicationRecord
  TASK_TYPES = %w[categories products bestsellers popular_categories category_images product_images].freeze

  validates :task_type, presence: true, uniqueness: true, inclusion: { in: TASK_TYPES }
  validates :schedule, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :due, -> { where('next_run_at <= ?', Time.current) }

  before_save :calculate_next_run

  def calculate_next_run
    return unless schedule.present?
    return self.next_run_at = nil unless enabled?
    
    begin
      cron = Fugit.parse(schedule)
      if cron
        next_time = cron.next_time
        # EtOrbi::EoTime нужно конвертировать в Time
        self.next_run_at = if next_time.is_a?(Time)
                             next_time
                           else
                             Time.parse(next_time.to_s)
                           end
      else
        self.next_run_at = nil
      end
    rescue => e
      Rails.logger.error "Failed to parse cron schedule '#{schedule}': #{e.message}"
      self.next_run_at = nil
    end
  end

  def due?
    next_run_at.present? && next_run_at <= Time.current
  end

  def mark_as_run!
    update!(last_run_at: Time.current)
    calculate_next_run
    save!
  end
end

