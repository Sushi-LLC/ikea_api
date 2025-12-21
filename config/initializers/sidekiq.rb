# Конфигурация Sidekiq
require 'sidekiq'
require 'sidekiq-cron'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
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

