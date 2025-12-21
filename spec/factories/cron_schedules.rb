FactoryBot.define do
  factory :cron_schedule do
    task_type { 'categories' }
    schedule { '0 2 * * *' } # Every day at 2:00 AM
    enabled { true }
    last_run_at { nil }
    # next_run_at будет рассчитан автоматически через before_save

    trait :disabled do
      enabled { false }
      next_run_at { nil }
    end
  end
end

