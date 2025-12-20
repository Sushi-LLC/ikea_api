# Задача для загрузки переменных окружения из .env файла
# Переопределяет задачи Capistrano для загрузки переменных из .env перед выполнением
namespace :deploy do
  desc "Загрузить переменные окружения из .env"
  task :load_env do
    on roles(:all) do |host|
      within shared_path do
        if test("[ -f .env ]")
          puts "✅ Файл .env найден в #{shared_path}"
        else
          puts "⚠️  Файл .env не найден в #{shared_path}"
        end
      end
    end
  end
  
  # Переопределяем задачу deploy:migrate для загрузки переменных из .env
  # Проверяем, существует ли задача перед переопределением
  if Rake::Task.task_defined?("deploy:migrate")
    Rake::Task["deploy:migrate"].clear_actions
  end
  
  desc "Run database migrations with .env variables"
  task :migrate do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env, :production) do
          env_file = "#{shared_path}/.env"
          release_dir = release_path
          # Загружаем asdf, переменные из .env и выполняем миграции
          # Используем bash -c для правильной загрузки переменных и asdf
          # Явно переходим в release_path перед выполнением bundle exec
          execute "bash -c 'cd #{release_dir} && export PATH=\"$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH\" && source $HOME/.asdf/asdf.sh 2>/dev/null || true && set -a && source #{env_file} 2>/dev/null || true && set +a && bundle exec rake db:migrate'"
        end
      end
    end
  end
  
  # Задача для выполнения seed
  desc "Run database seed with .env variables"
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env, :production) do
          env_file = "#{shared_path}/.env"
          release_dir = release_path
          # Загружаем asdf, переменные из .env и выполняем seed
          execute "bash -c 'cd #{release_dir} && export PATH=\"$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH\" && source $HOME/.asdf/asdf.sh 2>/dev/null || true && set -a && source #{env_file} 2>/dev/null || true && set +a && bundle exec rake db:seed'"
        end
      end
    end
  end
end

# Загружать .env перед выполнением задач деплоя
before "deploy:starting", "deploy:load_env"

# Выполнять seed после миграций
after "deploy:migrate", "deploy:seed"

