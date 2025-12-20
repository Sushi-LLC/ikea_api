source "https://rubygems.org"

ruby "3.3.0"

gem "rails", "~> 7.1.6"
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# Fast JSON API
gem "fast_jsonapi"

# JWT для аутентификации
gem "jwt"

# Валидация и обработка ошибок
gem "pry-rails"
gem "annotate"

# MongoDB синхронизация
gem "mongo", "~> 2.18"
gem "connection_pool", "~> 2.4"
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 1.12"

# Pagination
gem "kaminari"

# Swagger документация
gem "rswag"
gem "rswag-api"
gem "rswag-ui"

# Trestle Admin Panel
gem "trestle", "~> 0.9"
gem "trestle-auth", "~> 0.4"
gem "sprockets-rails", "~> 3.4"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
  
  # Capistrano для деплоя
  gem "capistrano", "~> 3.18"
  gem "capistrano-rails", "~> 1.6"
  gem "capistrano3-puma", "~> 5.2"
end

