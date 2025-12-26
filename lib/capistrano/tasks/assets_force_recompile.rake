namespace :deploy do
  desc 'Очистка кеша перед компиляцией assets'
  task :clear_cache_before_assets do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          # Очищаем кеш Rails
          execute :rake, 'tmp:cache:clear'
        end
      end
    end
  end
end

# Очищаем кеш перед компиляцией assets
before 'deploy:assets:precompile', 'deploy:clear_cache_before_assets'
