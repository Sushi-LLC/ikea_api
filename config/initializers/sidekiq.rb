# Конфигурация Sidekiq
require 'sidekiq'
require 'sidekiq-cron'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # Обработка ошибок для несуществующих классов задач (ActiveStorage)
  config.death_handlers << ->(job, _ex) do
    job_class = job['wrapped'] || job['class'] || job['job_class']
    if job_class && job_class.to_s.include?('ActiveStorage')
      Rails.logger.warn "Removing dead ActiveStorage job: #{job['jid']} (#{job_class})"
      begin
        # Удаляем задачу из очереди мертвых задач
        Sidekiq::DeadSet.new.delete(job['jid'])
      rescue => e
        Rails.logger.error "Failed to delete ActiveStorage job: #{e.message}"
      end
    end
  end
  
  # Загружаем cron задачи из базы данных при старте
  config.on(:startup) do
    begin
      CronManagerService.sync_all_schedules
    rescue => e
      Rails.logger.error "Failed to sync cron schedules on startup: #{e.message}"
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

