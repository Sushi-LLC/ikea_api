# Production server configuration
server "45.135.234.22", user: "deploy", roles: %w{app db web}

# SSH options (переопределяем из deploy.rb если нужно)
# set :ssh_options, {
#   keys: %w(~/.ssh/id_ed25519 ~/.ssh/id_rsa),
#   forward_agent: true,
#   auth_methods: %w(publickey),
#   verify_host_key: :never
# }
