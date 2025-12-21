FactoryBot.define do
  factory :parser_task do
    task_type { 'categories' }
    status { 'pending' }
    limit { nil }
    processed { 0 }
    created { 0 }
    updated { 0 }
    error_count { 0 }
    started_at { nil }
    completed_at { nil }
    error_message { nil }

    trait :running do
      status { 'running' }
      started_at { 1.hour.ago }
    end

    trait :completed do
      status { 'completed' }
      started_at { 2.hours.ago }
      completed_at { 1.hour.ago }
      processed { 100 }
      created { 50 }
      updated { 30 }
      errors { 5 }
    end

    trait :failed do
      status { 'failed' }
      started_at { 2.hours.ago }
      completed_at { 1.hour.ago }
      error_message { 'Test error' }
    end
  end
end

