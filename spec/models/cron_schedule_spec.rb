require 'rails_helper'

RSpec.describe CronSchedule, type: :model do
  describe 'validations' do
    subject { build(:cron_schedule) }
    
    it 'validates presence of task_type' do
      subject.task_type = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:task_type]).to be_present
    end
    
    it 'validates presence of schedule' do
      subject.schedule = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:schedule]).to be_present
    end
    
    it 'validates uniqueness of task_type' do
      create(:cron_schedule, task_type: 'categories')
      subject.task_type = 'categories'
      expect(subject).not_to be_valid
      expect(subject.errors[:task_type]).to be_present
    end
    
    it 'validates inclusion of task_type' do
      subject.task_type = 'invalid'
      expect(subject).not_to be_valid
      expect(subject.errors[:task_type]).to be_present
    end
  end

  describe 'scopes' do
    let!(:enabled_schedule) { create(:cron_schedule, task_type: 'categories', enabled: true) }
    let!(:disabled_schedule) { create(:cron_schedule, task_type: 'products', enabled: false) }

    it 'returns enabled schedules' do
      expect(CronSchedule.enabled).to include(enabled_schedule)
      expect(CronSchedule.enabled).not_to include(disabled_schedule)
    end

    it 'returns due schedules' do
      due_schedule = create(:cron_schedule, task_type: 'bestsellers', enabled: true)
      future_schedule = create(:cron_schedule, task_type: 'popular_categories', enabled: true)
      
      # Обновляем next_run_at напрямую, обходя before_save
      due_schedule.update_column(:next_run_at, 1.hour.ago)
      future_schedule.update_column(:next_run_at, 1.hour.from_now)
      
      expect(CronSchedule.due).to include(due_schedule)
      expect(CronSchedule.due).not_to include(future_schedule)
    end
  end

  describe '#calculate_next_run' do
    it 'calculates next run time for valid cron expression' do
      schedule = build(:cron_schedule, task_type: 'category_images', schedule: '0 2 * * *', enabled: true)
      schedule.calculate_next_run
      
      expect(schedule.next_run_at).to be_present
      expect(schedule.next_run_at).to be > Time.current
    end

    it 'does not calculate if disabled' do
      schedule = build(:cron_schedule, task_type: 'product_images', schedule: '0 2 * * *', enabled: false, next_run_at: nil)
      schedule.calculate_next_run
      
      expect(schedule.next_run_at).to be_nil
    end

    it 'handles invalid cron expression gracefully' do
      schedule = build(:cron_schedule, task_type: 'bestsellers', schedule: 'invalid', enabled: true, next_run_at: nil)
      
      expect { schedule.calculate_next_run }.not_to raise_error
      # Fugit.parse может вернуть nil или объект без next_time, проверяем что ошибки нет
      expect(schedule.next_run_at).to be_nil
    end
  end

  describe '#due?' do
    it 'returns true if next_run_at is in the past' do
      schedule = build(:cron_schedule, next_run_at: 1.hour.ago)
      expect(schedule.due?).to be true
    end

    it 'returns false if next_run_at is in the future' do
      schedule = build(:cron_schedule, next_run_at: 1.hour.from_now)
      expect(schedule.due?).to be false
    end

    it 'returns false if next_run_at is nil' do
      schedule = build(:cron_schedule, next_run_at: nil)
      expect(schedule.due?).to be false
    end
  end

  describe '#mark_as_run!' do
    it 'updates last_run_at and calculates next run' do
      schedule = create(:cron_schedule, task_type: 'popular_categories', last_run_at: nil)
      schedule.update_column(:next_run_at, 1.hour.ago)
      old_next_run = schedule.reload.next_run_at
      
      schedule.mark_as_run!
      schedule.reload
      
      expect(schedule.last_run_at).to be_present
      expect(schedule.next_run_at).to be_present
      expect(schedule.next_run_at).to be > old_next_run
    end
  end
end

