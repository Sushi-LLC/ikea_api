# Задача для загрузки переменных окружения из .env файла
# Загружает переменные из shared/.env и устанавливает их в default_env
namespace :deploy do
  desc "Загрузить переменные окружения из .env"
  task :load_env do
    on roles(:all) do |host|
      within shared_path do
        if test("[ -f .env ]")
          # Загрузить переменные из .env на сервере
          env_vars = capture("cat .env | grep -v '^#' | grep -v '^$'")
          env_hash = {}
          
          env_vars.split("\n").each do |line|
            key, value = line.split("=", 2)
            next if key.nil? || value.nil?
            key = key.strip
            value = value.strip
            # Удалить кавычки если есть
            value = value.gsub(/^["']|["']$/, '')
            env_hash[key] = value
          end
          
          # Установить переменные в SSHKit default_env
          # Это будет применяться ко всем командам
          SSHKit.config.default_env.merge!(env_hash)
          
          info "Загружено #{env_hash.keys.count} переменных из .env"
        else
          warn "Файл .env не найден в #{shared_path}"
        end
      end
    end
  end
end

# Загружать .env перед выполнением задач деплоя
before "deploy:starting", "deploy:load_env"

