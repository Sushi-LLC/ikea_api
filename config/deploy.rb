# config valid for current version and patch releases of Capistrano
lock "~> 3.20.0"

set :application, "ikea_api"
set :repo_url, "git@github.com:dmitryS1666/ikea_api.git"

# Default branch
set :branch, :main

# Deploy directory
set :deploy_to, "/var/www/ikea_api"

# Keep last 5 releases
set :keep_releases, 5

# Linked files (shared between deployments)
append :linked_files, "config/master.key", ".env"

# Linked directories (shared between deployments)
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "storage"

# Ruby version (asdf)
# asdf автоматически управляет PATH через shims
set :asdf_ruby_version, "3.3.0"
set :asdf_path, "$HOME/.asdf"

# Настройка PATH для asdf
set :default_env, {
  'PATH' => "$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH"
}

# Команды, которые должны использовать asdf
set :asdf_map_bins, %w{rake gem bundle ruby rails puma pumactl}

# SSH опции для загрузки asdf
set :ssh_options, {
  keys: %w(~/.ssh/id_ed25519 ~/.ssh/id_rsa),
  forward_agent: true,
  auth_methods: %w(publickey),
  verify_host_key: :never
}

# Обертка для команд с загрузкой asdf
def asdf_prefix
  "source $HOME/.asdf/asdf.sh &&"
end

# Puma configuration
set :puma_init_active_record, true
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_bind, "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log, "#{release_path}/log/puma.error.log"
set :puma_role, :app

# Rails assets
set :assets_roles, [:web, :app]

# Default value for :format is :airbrussh
set :format, :airbrussh

# Format options
set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
set :pty, true

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure
