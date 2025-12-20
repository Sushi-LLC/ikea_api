# Кастомные задачи для asdf
namespace :asdf do
  desc "Проверка установки asdf и Ruby"
  task :check do
    on roles(:app) do
      execute "source $HOME/.asdf/asdf.sh && asdf current ruby"
    end
  end

  desc "Установить Ruby версию для проекта"
  task :set_ruby_version do
    on roles(:app) do
      within release_path do
        execute "source $HOME/.asdf/asdf.sh && asdf local ruby #{fetch(:asdf_ruby_version)}"
      end
    end
  end
end

# Загружать asdf перед выполнением команд
before "deploy:starting", "asdf:check"

