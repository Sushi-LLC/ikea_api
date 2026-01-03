namespace :deploy do
  namespace :sidekiq do
    desc 'Restart Sidekiq via systemd'
    task :restart do
      on roles(:app) do
        within release_path do
          execute :sudo, 'systemctl', 'restart', 'ikea_back_sidekiq'
        end
        info '✅ Sidekiq перезапущен через systemd'
      end
    end

    desc 'Start Sidekiq via systemd'
    task :start do
      on roles(:app) do
        execute :sudo, 'systemctl', 'start', 'ikea_back_sidekiq'
        info '✅ Sidekiq запущен через systemd'
      end
    end

    desc 'Stop Sidekiq via systemd'
    task :stop do
      on roles(:app) do
        execute :sudo, 'systemctl', 'stop', 'ikea_back_sidekiq'
        info '✅ Sidekiq остановлен через systemd'
      end
    end

    desc 'Status of Sidekiq via systemd'
    task :status do
      on roles(:app) do
        execute :sudo, 'systemctl', 'status', 'ikea_back_sidekiq', '--no-pager'
      end
    end
  end
end

# Автоматический перезапуск Sidekiq после деплоя
after 'deploy:published', 'deploy:sidekiq:restart'

