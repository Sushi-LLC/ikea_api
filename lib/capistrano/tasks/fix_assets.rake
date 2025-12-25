namespace :deploy do
  desc "Исправить assets и перезагрузить Nginx"
  task :fix_assets do
    on roles(:web) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          # Пересобираем assets
          execute :bundle, "exec rails assets:precompile"
          
          # Проверяем наличие assets
          execute :ls, "-la public/assets/trestle/ | head -10"
        end
      end
    end
    
    # Перезагружаем Nginx
    on roles(:web) do
      execute :sudo, "systemctl reload nginx"
    end
  end
end

