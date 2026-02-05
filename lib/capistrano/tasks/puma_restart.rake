namespace :deploy do
  namespace :puma do
    desc 'Restart Puma via systemd'
    task :restart do
      on roles(:app) do
        execute :sudo, 'systemctl', 'restart', 'ikea_back_puma'
        execute :sudo, 'systemctl', 'restart', 'ikea_back_sidekiq'
        info '✅ Puma и Sidekiq перезапущены через systemd'
      end
    end

    desc 'Stop Puma via systemd'
    task :stop do
      on roles(:app) do
        execute :sudo, 'systemctl', 'stop', 'ikea_back_puma'
        execute :sudo, 'systemctl', 'stop', 'ikea_back_sidekiq'
        info '✅ Puma и Sidekiq остановлены'
      end
    end

    desc 'Start Puma via systemd'
    task :start do
      on roles(:app) do
        execute :sudo, 'systemctl', 'start', 'ikea_back_puma'
        execute :sudo, 'systemctl', 'start', 'ikea_back_sidekiq'
        info '✅ Puma и Sidekiq запущены'
      end
    end

    desc 'Check Puma status via systemd'
    task :status do
      on roles(:app) do
        execute :sudo, 'systemctl', 'status', 'ikea_back_puma', '--no-pager'
      end
    end
  end
end

# Автоматический перезапуск Puma после успешного деплоя
after 'deploy:published', 'deploy:puma:restart'

