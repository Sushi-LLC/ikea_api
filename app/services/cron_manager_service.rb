# Сервис для управления cron задачами через Sidekiq-Cron
class CronManagerService
  class << self
    # Создать или обновить cron задачу
    def setup_cron_schedule(cron_schedule)
      return unless cron_schedule.enabled?
      
      job_name = "parser_#{cron_schedule.task_type}"
      
      # Удаляем существующую задачу, если есть
      Sidekiq::Cron::Job.find(job_name)&.destroy
      
      # Создаем новую задачу
      # Sidekiq-Cron требует строковое имя класса
      job_class_name = job_class_for_task_type(cron_schedule.task_type).to_s
      
      Sidekiq::Cron::Job.create(
        name: job_name,
        cron: cron_schedule.schedule,
        class: job_class_name,
        args: []
      )
      
      Rails.logger.info "Cron schedule created: #{job_name} with schedule #{cron_schedule.schedule}"
    end

    # Удалить cron задачу
    def remove_cron_schedule(cron_schedule)
      job_name = "parser_#{cron_schedule.task_type}"
      job = Sidekiq::Cron::Job.find(job_name)
      
      if job
        job.destroy
        Rails.logger.info "Cron schedule removed: #{job_name}"
      end
    end

    # Синхронизировать все cron расписания из базы данных
    def sync_all_schedules
      CronSchedule.enabled.find_each do |schedule|
        setup_cron_schedule(schedule)
      end
      
      # Удаляем задачи, которые отключены или удалены из БД
      active_task_types = CronSchedule.enabled.pluck(:task_type)
      Sidekiq::Cron::Job.all.each do |job|
        if job.name.start_with?('parser_') && !active_task_types.include?(job.name.sub('parser_', ''))
          job.destroy
          Rails.logger.info "Removed inactive cron job: #{job.name}"
        end
      end
    end

    # Проверить и запустить задачи, которые должны выполниться
    def check_and_run_due_tasks
      CronSchedule.enabled.due.find_each do |schedule|
        job_class = job_class_for_task_type(schedule.task_type)
        job_class.perform_later
        
        schedule.mark_as_run!
        Rails.logger.info "Scheduled task #{schedule.task_type} executed"
      end
    end

    private

    def job_class_for_task_type(task_type)
      case task_type
      when 'categories'
        ParseCategoriesJob
      when 'products'
        ParseProductsJob
      when 'bestsellers'
        ParseBestsellersJob
      when 'popular_categories'
        ParsePopularCategoriesJob
      when 'category_images'
        DownloadCategoryImagesJob
      when 'product_images'
        DownloadProductImagesJob
      else
        raise ArgumentError, "Unknown task type: #{task_type}"
      end
    end
  end
end

