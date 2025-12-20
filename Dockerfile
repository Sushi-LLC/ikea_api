# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.0
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code (исключая public/, он будет заменен React build)
COPY . .

# Удаляем содержимое public/ (кроме .keep и robots.txt)
# React build будет скопирован позже
RUN rm -rf public/* && \
    mkdir -p public && \
    touch public/.keep

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Stage 2: Build React (если React в отдельном репозитории)
# Раскомментируйте и настройте, если React в отдельном репозитории:
# FROM node:20-alpine as react-build
# WORKDIR /app
# ARG REACT_REPO_URL
# ARG REACT_BRANCH=main
# RUN git clone -b ${REACT_BRANCH} ${REACT_REPO_URL} . || echo "React repo not provided, skipping"
# RUN npm ci --only=production && npm run build || echo "React build skipped"

# Или если React в поддиректории frontend/:
# FROM node:20-alpine as react-build
# WORKDIR /app
# COPY frontend/package*.json ./
# RUN npm ci --only=production
# COPY frontend/ ./
# RUN npm run build


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl postgresql-client socat && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Copy React build to public/ (после Rails кода, чтобы не перезаписать)
# Раскомментируйте, если используете multi-stage build для React:
# COPY --from=react-build /app/build /rails/public

# ПРИМЕЧАНИЕ: Если React собирается в CI/CD отдельно,
# то перед docker build нужно скопировать React build в public/:
#   cp -r /path/to/react-app/build/* public/

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log tmp
# Note: We need to run as root to bind to port 80, or use socat for port forwarding
USER root

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Healthcheck для Docker (увеличен интервал для первого запуска)
HEALTHCHECK --interval=5s --timeout=3s --retries=5 --start-period=30s \
  CMD curl -f http://localhost:80/up || exit 1

# Start the server by default, this can be overwritten at runtime
# Используем порт 80 для kamal-proxy, проксируем на 3000 через socat
EXPOSE 80
# Entrypoint обработает запуск Rails и socat в правильном порядке
CMD ["./bin/rails", "server"]
