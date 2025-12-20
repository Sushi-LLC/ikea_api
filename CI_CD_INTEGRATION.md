# 🔄 Интеграция CI/CD для React + Rails

## 📋 Ответы на вопросы

### 1. Нужно ли переделать CI/CD для React приложения?

**ДА**, нужно интегрировать сборку React в процесс деплоя Rails. Есть два варианта:

#### Вариант A: Multi-stage build в Dockerfile (РЕКОМЕНДУЕТСЯ)
- React собирается внутри Dockerfile
- Один CI/CD workflow для обоих репозиториев
- Автоматическая синхронизация версий

#### Вариант B: Отдельные CI/CD с артефактами
- React CI/CD собирает и сохраняет артефакты
- Rails CI/CD скачивает артефакты и копирует в `public/`
- Больше гибкости, но сложнее

### 2. Не будет ли слетать `public/` при деплое Rails?

**ДА, это проблема!** Текущий `COPY . .` перезапишет `public/`.

**Решение:** Использовать multi-stage build:
1. Копировать Rails код (исключая `public/`)
2. Собрать React
3. Скопировать React build в `public/` ПОСЛЕ копирования Rails кода

### 3. Правильно ли, что React забирает данные из Rails API?

**ДА, это правильная архитектура!**

```
React SPA (клиент) → fetch('/api/v1/products') → Rails API → PostgreSQL
```

Это стандартная архитектура:
- ✅ Разделение ответственности
- ✅ RESTful API
- ✅ Независимое масштабирование
- ✅ Возможность использовать API для других клиентов (мобильные приложения)

---

## 🔧 Решение: Multi-stage Build в Dockerfile

### Шаг 1: Обновить Dockerfile

```dockerfile
# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.0
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base
WORKDIR /rails
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Stage 1: Build Rails
FROM base as rails-build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Копируем Rails код (исключая public/)
COPY . .
RUN rm -rf public/*

# Stage 2: Build React
FROM node:20-alpine as react-build
WORKDIR /app

# Если React приложение в отдельном репозитории, используйте git clone
# ARG REACT_REPO_URL
# ARG REACT_BRANCH=main
# RUN git clone -b ${REACT_BRANCH} ${REACT_REPO_URL} .

# Или если React в том же репозитории (в поддиректории frontend/)
COPY frontend/package*.json ./
RUN npm ci --only=production

COPY frontend/ ./
RUN npm run build

# Stage 3: Final image
FROM base
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl postgresql-client socat && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Копируем Rails
COPY --from=rails-build /usr/local/bundle /usr/local/bundle
COPY --from=rails-build /rails /rails

# Копируем React build в public/ ПОСЛЕ Rails
COPY --from=react-build /app/build /rails/public

RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log tmp
USER root

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
HEALTHCHECK --interval=5s --timeout=3s --retries=5 --start-period=30s \
  CMD curl -f http://localhost:80/up || exit 1

EXPOSE 80
CMD ["./bin/rails", "server"]
```

### Шаг 2: Обновить .dockerignore

```dockerignore
# Игнорируем public/ из Rails (будет заменен React build)
/public/*
!/public/.keep
!/public/robots.txt
```

### Шаг 3: GitHub Actions Workflow для Rails

```yaml
# .github/workflows/deploy.yml
name: Deploy Rails + React

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Rails
        uses: actions/checkout@v4
        with:
          path: rails-app
      
      - name: Checkout React
        uses: actions/checkout@v4
        with:
          repository: your-org/react-app  # Замените на ваш репозиторий
          path: react-app
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./rails-app
          file: ./rails-app/Dockerfile
          push: true
          tags: sushi0590/ikea_api:latest
          build-args: |
            REACT_REPO_URL=https://github.com/your-org/react-app.git
            REACT_BRANCH=main
          cache-from: type=registry,ref=sushi0590/ikea_api:buildcache
          cache-to: type=registry,ref=sushi0590/ikea_api:buildcache,mode=max
      
      - name: Deploy with Kamal
        run: |
          cd rails-app
          kamal deploy
        env:
          KAMAL_REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Шаг 4: Альтернатива - React в том же репозитории

Если React приложение в поддиректории `frontend/`:

```dockerfile
# В Dockerfile
FROM node:20-alpine as react-build
WORKDIR /app

# Копируем React из поддиректории
COPY frontend/package*.json ./
RUN npm ci --only=production
COPY frontend/ ./
RUN npm run build
```

---

## 🔄 Вариант B: Отдельные CI/CD с артефактами

### React CI/CD (.github/workflows/build-react.yml)

```yaml
name: Build React Frontend

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: react-build
          path: build/
          retention-days: 7
```

### Rails CI/CD (.github/workflows/deploy-rails.yml)

```yaml
name: Deploy Rails

on:
  workflow_run:
    workflows: ["Build React Frontend"]
    types: [completed]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Download React build
        uses: actions/download-artifact@v4
        with:
          name: react-build
          path: public/
          workflow: build-react.yml  # ID workflow для React
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: sushi0590/ikea_api:latest
      
      - name: Deploy with Kamal
        run: kamal deploy
```

---

## 🎯 Рекомендация

**Используйте Вариант A (Multi-stage build):**

✅ Проще в настройке
✅ Один workflow
✅ Автоматическая синхронизация версий
✅ Меньше точек отказа

**Если React в отдельном репозитории:**
- Используйте `git clone` в Dockerfile
- Или используйте GitHub Actions для клонирования перед build

**Если React в том же репозитории:**
- Просто скопируйте `frontend/` в Dockerfile

---

## 📝 Настройка API endpoints в React

```javascript
// src/config/api.js
const API_BASE_URL = process.env.REACT_APP_API_URL || '/api/v1';

export const apiClient = {
  get: (endpoint) => fetch(`${API_BASE_URL}${endpoint}`),
  post: (endpoint, data) => fetch(`${API_BASE_URL}${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  })
};
```

---

## ✅ Итоговая архитектура

```
┌─────────────────┐
│  React SPA      │
│  (public/)      │
└────────┬────────┘
         │ fetch('/api/v1/products')
         ▼
┌─────────────────┐
│  Rails API      │
│  /api/v1/*      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  PostgreSQL     │
└─────────────────┘
```

**Все в одном контейнере, один деплой, простая архитектура!**

