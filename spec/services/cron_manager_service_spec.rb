require 'rails_helper'

RSpec.describe CronManagerService do
  let(:cron_schedule) { create(:cron_schedule, task_type: 'categories', schedule: '0 2 * * *') }

  describe '.setup_cron_schedule' do
    it 'creates Sidekiq cron job' do
      allow(Sidekiq::Cron::Job).to receive(:find).and_return(nil)
      allow(Sidekiq::Cron::Job).to receive(:create)
      
      CronManagerService.setup_cron_schedule(cron_schedule)
      
      expect(Sidekiq::Cron::Job).to have_received(:create).with(
        name: 'parser_categories',
        cron: '0 2 * * *',
        class: 'ParseCategoriesJob',
        args: []
      )
    end

    it 'removes existing job before creating new one' do
      existing_job = double('job')
      allow(Sidekiq::Cron::Job).to receive(:find).and_return(existing_job)
      allow(existing_job).to receive(:destroy)
      allow(Sidekiq::Cron::Job).to receive(:create)
      
      CronManagerService.setup_cron_schedule(cron_schedule)
      
      expect(existing_job).to have_received(:destroy)
    end

    it 'does not create job if schedule is disabled' do
      disabled_schedule = create(:cron_schedule, enabled: false)
      
      expect(Sidekiq::Cron::Job).not_to receive(:create)
      CronManagerService.setup_cron_schedule(disabled_schedule)
    end
  end

  describe '.remove_cron_schedule' do
    it 'removes Sidekiq cron job' do
      job = double('job')
      allow(Sidekiq::Cron::Job).to receive(:find).and_return(job)
      allow(job).to receive(:destroy)
      
      CronManagerService.remove_cron_schedule(cron_schedule)
      
      expect(job).to have_received(:destroy)
    end

    it 'handles missing job gracefully' do
      allow(Sidekiq::Cron::Job).to receive(:find).and_return(nil)
      
      expect { CronManagerService.remove_cron_schedule(cron_schedule) }.not_to raise_error
    end
  end

  describe '.sync_all_schedules' do
    it 'syncs all enabled schedules' do
      enabled1 = create(:cron_schedule, enabled: true, task_type: 'categories')
      enabled2 = create(:cron_schedule, enabled: true, task_type: 'products')
      disabled = create(:cron_schedule, enabled: false, task_type: 'bestsellers')
      
      allow(CronManagerService).to receive(:setup_cron_schedule)
      allow(Sidekiq::Cron::Job).to receive(:all).and_return([])
      
      CronManagerService.sync_all_schedules
      
      expect(CronManagerService).to have_received(:setup_cron_schedule).with(enabled1)
      expect(CronManagerService).to have_received(:setup_cron_schedule).with(enabled2)
      expect(CronManagerService).not_to have_received(:setup_cron_schedule).with(disabled)
    end
  end

  describe '.check_and_run_due_tasks' do
    it 'runs due tasks' do
      due_schedule = create(:cron_schedule, enabled: true, task_type: 'categories')
      future_schedule = create(:cron_schedule, enabled: true, task_type: 'products')
      
      # Обновляем next_run_at напрямую, обходя before_save
      due_schedule.update_column(:next_run_at, 1.hour.ago)
      future_schedule.update_column(:next_run_at, 1.hour.from_now)
      
      allow(ParseCategoriesJob).to receive(:perform_later)
      allow(ParseProductsJob).to receive(:perform_later)
      
      CronManagerService.check_and_run_due_tasks
      
      expect(ParseCategoriesJob).to have_received(:perform_later)
      expect(ParseProductsJob).not_to have_received(:perform_later)
      expect(due_schedule.reload.last_run_at).to be_present
    end
  end
end

