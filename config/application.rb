require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Загружаем переменные окружения из .env файла (только в development и test)
if defined?(Dotenv)
  Dotenv.load
end

module IkeaApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    # ВАЖНО: api_only = false для поддержки ActiveAdmin
    # API-only функциональность обеспечивается через namespace :api в routes
    config.api_only = false
    
    # Для ActiveAdmin нужны helpers и views
    config.force_ssl = false
    config.action_controller.include_all_helpers = true
    
    # Добавляем middleware для сессий (нужно для Swagger авторизации)
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, 
      key: '_ikea_api_session',
      secret: Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE'] || 'development_secret_key_change_in_production',
      same_site: :lax,
      # В production отключаем secure, т.к. используем HTTP через kamal-proxy
      # SSL будет настроен на уровне proxy при привязке домена
      secure: Rails.env.production? && ENV['FORCE_SSL_COOKIES'] == 'true'
    config.middleware.use ActionDispatch::Flash
    
    # Redis для кэширования
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
      password: ENV['REDIS_PASSWORD'],
      namespace: 'ikea_api',
      expires_in: 1.hour
    }
  end
end
