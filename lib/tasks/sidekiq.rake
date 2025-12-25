# Rake задачи для управления Sidekiq
namespace :sidekiq do
  desc "Очистить очередь Sidekiq от старых задач ActiveStorage"
  task clear_active_storage_jobs: :environment do
    require 'sidekiq/api'
    
    puts "=" * 60
    puts "Очистка очереди Sidekiq от задач ActiveStorage"
    puts "=" * 60
    
    # Очищаем очередь default
    queue = Sidekiq::Queue.new('default')
    active_storage_jobs = queue.select { |job| job.klass.to_s.include?('ActiveStorage') || job.args.first&.dig('wrapped')&.include?('ActiveStorage') }
    
    if active_storage_jobs.any?
      puts "\nНайдено задач ActiveStorage в очереди 'default': #{active_storage_jobs.count}"
      active_storage_jobs.each do |job|
        puts "  Удаление: #{job.klass} (JID: #{job.jid})"
        job.delete
      end
      puts "✓ Удалено задач из очереди: #{active_storage_jobs.count}"
    else
      puts "\n✓ Задач ActiveStorage в очереди 'default' не найдено"
    end
    
    # Очищаем очередь мертвых задач (DeadSet)
    dead_set = Sidekiq::DeadSet.new
    dead_active_storage_jobs = dead_set.select { |job| job.klass.to_s.include?('ActiveStorage') || job.item['wrapped']&.include?('ActiveStorage') }
    
    if dead_active_storage_jobs.any?
      puts "\nНайдено задач ActiveStorage в DeadSet: #{dead_active_storage_jobs.count}"
      dead_active_storage_jobs.each do |job|
        puts "  Удаление: #{job.klass} (JID: #{job.jid})"
        dead_set.delete(job.jid)
      end
      puts "✓ Удалено задач из DeadSet: #{dead_active_storage_jobs.count}"
    else
      puts "\n✓ Задач ActiveStorage в DeadSet не найдено"
    end
    
    # Очищаем очередь отложенных задач (ScheduledSet)
    scheduled_set = Sidekiq::ScheduledSet.new
    scheduled_active_storage_jobs = scheduled_set.select { |job| job.klass.to_s.include?('ActiveStorage') || job.item['wrapped']&.include?('ActiveStorage') }
    
    if scheduled_active_storage_jobs.any?
      puts "\nНайдено задач ActiveStorage в ScheduledSet: #{scheduled_active_storage_jobs.count}"
      scheduled_active_storage_jobs.each do |job|
        puts "  Удаление: #{job.klass} (JID: #{job.jid})"
        scheduled_set.delete(job.jid)
      end
      puts "✓ Удалено задач из ScheduledSet: #{scheduled_active_storage_jobs.count}"
    else
      puts "\n✓ Задач ActiveStorage в ScheduledSet не найдено"
    end
    
    # Очищаем очередь повторных попыток (RetrySet)
    retry_set = Sidekiq::RetrySet.new
    retry_active_storage_jobs = retry_set.select { |job| job.klass.to_s.include?('ActiveStorage') || job.item['wrapped']&.include?('ActiveStorage') }
    
    if retry_active_storage_jobs.any?
      puts "\nНайдено задач ActiveStorage в RetrySet: #{retry_active_storage_jobs.count}"
      retry_active_storage_jobs.each do |job|
        puts "  Удаление: #{job.klass} (JID: #{job.jid})"
        job.delete
      end
      puts "✓ Удалено задач из RetrySet: #{retry_active_storage_jobs.count}"
    else
      puts "\n✓ Задач ActiveStorage в RetrySet не найдено"
    end
    
    puts "\n" + "=" * 60
    puts "Очистка завершена!"
    puts "=" * 60
  end
  
  desc "Показать статистику очередей Sidekiq"
  task stats: :environment do
    require 'sidekiq/api'
    
    puts "=" * 60
    puts "Статистика Sidekiq"
    puts "=" * 60
    
    # Очередь default
    queue = Sidekiq::Queue.new('default')
    puts "\nОчередь 'default':"
    puts "  Всего задач: #{queue.size}"
    puts "  Задач ActiveStorage: #{queue.count { |job| job.klass.to_s.include?('ActiveStorage') || job.args.first&.dig('wrapped')&.include?('ActiveStorage') }}"
    
    # DeadSet
    dead_set = Sidekiq::DeadSet.new
    puts "\nDeadSet (мертвые задачи):"
    puts "  Всего задач: #{dead_set.size}"
    puts "  Задач ActiveStorage: #{dead_set.count { |job| job.klass.to_s.include?('ActiveStorage') || job.item['wrapped']&.include?('ActiveStorage') }}"
    
    # ScheduledSet
    scheduled_set = Sidekiq::ScheduledSet.new
    puts "\nScheduledSet (отложенные задачи):"
    puts "  Всего задач: #{scheduled_set.size}"
    puts "  Задач ActiveStorage: #{scheduled_set.count { |job| job.klass.to_s.include?('ActiveStorage') || job.item['wrapped']&.include?('ActiveStorage') }}"
    
    # RetrySet
    retry_set = Sidekiq::RetrySet.new
    puts "\nRetrySet (повторные попытки):"
    puts "  Всего задач: #{retry_set.size}"
    puts "  Задач ActiveStorage: #{retry_set.count { |job| job.klass.to_s.include?('ActiveStorage') || job.item['wrapped']&.include?('ActiveStorage') }}"
    
    puts "\n" + "=" * 60
  end
  
  desc "Очистить все очереди Sidekiq (ОСТОРОЖНО!)"
  task clear_all: :environment do
    require 'sidekiq/api'
    
    puts "=" * 60
    puts "ОЧИСТКА ВСЕХ ОЧЕРЕДЕЙ SIDEKIQ"
    puts "=" * 60
    puts "\n⚠ ВНИМАНИЕ: Это удалит ВСЕ задачи из всех очередей!"
    puts "Нажмите Ctrl+C для отмены или Enter для продолжения..."
    STDIN.gets
    
    # Очищаем все очереди
    Sidekiq::Queue.all.each do |queue|
      size = queue.size
      queue.clear
      puts "✓ Очищена очередь '#{queue.name}': #{size} задач"
    end
    
    # Очищаем DeadSet
    dead_set = Sidekiq::DeadSet.new
    dead_size = dead_set.size
    dead_set.clear
    puts "✓ Очищен DeadSet: #{dead_size} задач"
    
    # Очищаем ScheduledSet
    scheduled_set = Sidekiq::ScheduledSet.new
    scheduled_size = scheduled_set.size
    scheduled_set.clear
    puts "✓ Очищен ScheduledSet: #{scheduled_size} задач"
    
    # Очищаем RetrySet
    retry_set = Sidekiq::RetrySet.new
    retry_size = retry_set.size
    retry_set.clear
    puts "✓ Очищен RetrySet: #{retry_size} задач"
    
    puts "\n" + "=" * 60
    puts "Очистка завершена!"
    puts "=" * 60
  end
end

