class ApplicationJob < ActiveJob::Base
  # Используем Sidekiq как адаптер
  # Настраивается в config/environments/*.rb
  
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
  
  # Базовые методы для всех задач парсинга
  protected
  
  def create_parser_task(task_type, limit: nil)
    ParserTask.create!(
      task_type: task_type,
      status: 'pending',
      limit: limit
    )
  end
  
  # Проверить, остановлена ли задача
  def task_stopped?(task)
    task.reload.status == 'failed' && task.error_message&.include?('Остановлено вручную')
  end
  
  # Выбросить исключение, если задача остановлена
  def check_task_not_stopped!(task)
    if task_stopped?(task)
      Rails.logger.info "Task #{task.id} was stopped, aborting job execution"
      raise StandardError.new('Task was stopped manually')
    end
  end
  
  def notify_started(task_type, limit: nil)
    TelegramService.send_parser_started(task_type, limit: limit)
  end
  
  def notify_completed(task_type, stats)
    TelegramService.send_parser_completed(task_type, stats)
  end
  
  def notify_error(task_type, error)
    TelegramService.send_parser_error(task_type, error)
  end
end

