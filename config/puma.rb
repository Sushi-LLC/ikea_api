# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

rails_env = ENV.fetch("RAILS_ENV") { "development" }

if rails_env == "production"
  # If you are running more than 1 thread per process, the workers count
  # should be equal to the number of processors (CPU cores) in production.
  #
  # It defaults to 1 because it's impossible to reliably detect how many
  # CPU cores are available. Make sure to set the `WEB_CONCURRENCY` environment
  # variable to match the number of processors.
  worker_count = Integer(ENV.fetch("WEB_CONCURRENCY") { 1 })
  if worker_count > 1
    workers worker_count
  else
    preload_app!
  end
end
# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
# В production используем Unix socket для лучшей производительности
# Capistrano3-puma плагин автоматически устанавливает bind через переменные окружения
if rails_env == "production"
  # Если PUMA_BIND установлен (Capistrano), используем его
  # Иначе используем Unix socket по умолчанию
  if ENV["PUMA_BIND"]
    # Capistrano установит это через deploy.rb
  else
    # Fallback для ручного запуска
    bind "unix://#{File.expand_path("../../shared/tmp/sockets/puma.sock", __dir__)}"
  end
else
  port ENV.fetch("PORT") { 3000 }
end

# Specifies the `environment` that Puma will run in.
environment rails_env

# Specifies the `pidfile` that Puma will use.
# Capistrano установит это через переменные окружения
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# State file для Capistrano (в production)
# Capistrano установит это через переменные окружения
if rails_env == "production" && ENV["PUMA_STATE"]
  state_path ENV["PUMA_STATE"]
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
