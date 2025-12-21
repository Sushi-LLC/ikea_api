# Инициализация парсера при старте приложения
Rails.application.config.after_initialize do
  # Синхронизируем cron расписания при старте
  if defined?(Rails::Server) || defined?(Puma::CLI)
    begin
      CronManagerService.sync_all_schedules
      Rails.logger.info "Parser cron schedules synchronized"
    rescue => e
      Rails.logger.error "Failed to sync cron schedules: #{e.message}"
    end
  end
end


