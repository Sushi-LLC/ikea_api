# 🔄 План миграции с Kamal на классический деплой

## 📋 Обзор

Миграция с Kamal (Docker) на классическую архитектуру:
- **Nginx** на сервере (уже работает)
- **Passenger** или **Puma** для Rails приложения
- **Capistrano** для деплоя

---

## 🎯 Шаг 1: Исправление фронтенда (ПРИОРИТЕТ)

### 1.1. Проверить конфигурацию Nginx для фронтенда

```bash
# На сервере
sudo cat /etc/nginx/sites-available/ikea_front.conf
```

### 1.2. Исправить upstream для фронтенда

Если фронтенд на `/ikea_front/`, убедитесь что:
- Upstream указывает на правильный порт (3000 для Next.js или статика)
- Путь к файлам корректен: `/var/www/ikea_frontend/dist`

### 1.3. Проверить права доступа

```bash
sudo chown -R www-data:www-data /var/www/ikea_frontend
sudo chmod -R 755 /var/www/ikea_frontend
```

### 1.4. Перезагрузить Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🎯 Шаг 2: Выбор между Passenger и Puma

### Passenger (РЕКОМЕНДУЕТСЯ для production)

**Плюсы:**
- ✅ Автоматическое управление процессами
- ✅ Встроенная интеграция с Nginx
- ✅ Автоматический перезапуск при изменениях
- ✅ Лучше для production

**Минусы:**
- ⚠️ Нужна установка Passenger модуля для Nginx
- ⚠️ Больше зависимостей

### Puma

**Плюсы:**
- ✅ Проще в настройке
- ✅ Меньше зависимостей
- ✅ Хорошо для небольших приложений

**Минусы:**
- ⚠️ Нужен systemd service для управления
- ⚠️ Нужно вручную настраивать перезапуск

**Рекомендация:** Используйте **Passenger** для production.

---

## 🎯 Шаг 3: Установка зависимостей на сервере

### 3.1. Ruby и зависимости

```bash
# Установить Ruby (если еще не установлен)
sudo apt update
sudo apt install -y ruby-full build-essential

# Или через rbenv/rvm (рекомендуется)
# См. инструкции ниже

# Установить Node.js (для asset pipeline)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Установить PostgreSQL клиент
sudo apt install -y postgresql-client libpq-dev

# Установить Redis (если используется)
sudo apt install -y redis-server
```

### 3.2. Установка Passenger

```bash
# Добавить репозиторий Passenger
sudo apt install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger focal main > /etc/apt/sources.list.d/passenger.list'
sudo apt update

# Установить Passenger и модуль для Nginx
sudo apt install -y passenger libnginx-mod-http-passenger

# Проверить установку
sudo /usr/bin/passenger-config validate-install
```

### 3.3. Или установка Puma (альтернатива)

```bash
# Puma устанавливается через Gemfile
# Нужно только создать systemd service (см. ниже)
```

---

## 🎯 Шаг 4: Настройка Capistrano

### 4.1. Добавить Capistrano в Gemfile

```ruby
# Gemfile
group :development do
  gem 'capistrano', '~> 3.18'
  gem 'capistrano-rails', '~> 1.6'
  gem 'capistrano-passenger', '~> 0.2.1'  # для Passenger
  # или
  # gem 'capistrano3-puma', '~> 5.2'  # для Puma
  gem 'capistrano-rbenv', '~> 2.2'  # если используете rbenv
end
```

### 4.2. Установить Capistrano

```bash
bundle install
cap install
```

### 4.3. Настроить Capfile

```ruby
# Capfile
require 'capistrano/rails'
require 'capistrano/passenger'  # для Passenger
# или
# require 'capistrano3/puma'  # для Puma
require 'capistrano/rbenv'  # если используете rbenv

# Загрузить кастомные задачи
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
```

### 4.4. Настроить config/deploy.rb

```ruby
# config/deploy.rb
lock '~> 3.18.0'

set :application, 'ikea_api'
set :repo_url, 'git@github.com:your-org/ikea_api.git'
set :branch, 'main'

# Деплой в директорию
set :deploy_to, '/var/www/ikea_api'

# Держать последние 5 релизов
set :keep_releases, 5

# Симлинки для shared файлов
append :linked_files, 'config/master.key', '.env'
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'storage'

# Ruby версия (если используете rbenv)
set :rbenv_type, :user
set :rbenv_ruby, '3.3.0'

# Passenger
set :passenger_restart_with_touch, true

# Или Puma
# set :puma_init_active_record, true
```

### 4.5. Настроить config/deploy/production.rb

```ruby
# config/deploy/production.rb
server '45.135.234.22', user: 'deploy', roles: %w{app db web}

set :ssh_options, {
  keys: %w(~/.ssh/id_ed25519),
  forward_agent: true,
  auth_methods: %w(publickey)
}
```

---

## 🎯 Шаг 5: Настройка Nginx для Passenger

### 5.1. Обновить config/nginx/ikea_api.conf

```nginx
# Upstream для Rails API через Passenger
upstream ikea_api_backend {
    # Passenger автоматически управляет процессами
    server unix:/var/www/ikea_api/shared/tmp/sockets/passenger.sock;
    # Или через TCP (если нужно):
    # server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name 45.135.234.22;

    # Passenger для Rails
    root /var/www/ikea_api/current/public;
    
    passenger_enabled on;
    passenger_ruby /home/deploy/.rbenv/versions/3.3.0/bin/ruby;  # путь к Ruby
    passenger_app_env production;
    passenger_min_instances 1;
    
    # API endpoints
    location /api {
        passenger_enabled on;
        # или проксировать:
        # proxy_pass http://ikea_api_backend;
    }
    
    # Admin
    location /admin {
        passenger_enabled on;
    }
    
    # Swagger
    location /api-docs {
        passenger_enabled on;
    }
    
    # Health check
    location /up {
        passenger_enabled on;
    }
    
    # Frontend
    location /ikea_front/ {
        alias /var/www/ikea_frontend/dist/;
        try_files $uri $uri/ /ikea_front/index.html;
    }
}
```

### 5.2. Или для Puma (альтернатива)

```nginx
upstream ikea_api_backend {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    server_name 45.135.234.22;
    
    # API endpoints
    location /api {
        proxy_pass http://ikea_api_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # ... остальное аналогично
}
```

---

## 🎯 Шаг 6: Systemd service для Puma (если используете Puma)

### 6.1. Создать /etc/systemd/system/ikea_api.service

```ini
[Unit]
Description=IKEA API Puma Server
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/ikea_api/current
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/home/deploy/.rbenv/versions/3.3.0/bin/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 6.2. Включить и запустить

```bash
sudo systemctl enable ikea_api
sudo systemctl start ikea_api
sudo systemctl status ikea_api
```

---

## 🎯 Шаг 7: Подготовка сервера

### 7.1. Создать пользователя deploy (если еще нет)

```bash
sudo adduser deploy
sudo usermod -aG sudo deploy
```

### 7.2. Настроить SSH ключи

```bash
# На локальной машине
ssh-copy-id deploy@45.135.234.22
```

### 7.3. Создать директории на сервере

```bash
sudo mkdir -p /var/www/ikea_api
sudo chown deploy:deploy /var/www/ikea_api
```

---

## 🎯 Шаг 8: Первый деплой

### 8.1. Настроить secrets на сервере

```bash
# Скопировать .env и config/master.key в shared/
# (Capistrano создаст симлинки автоматически)
```

### 8.2. Деплой

```bash
# На локальной машине
cap production deploy
```

---

## 📋 Чек-лист миграции

- [ ] Исправлен фронтенд (работает через Nginx)
- [ ] Выбран Passenger или Puma
- [ ] Установлены зависимости на сервере
- [ ] Настроен Capistrano
- [ ] Обновлена конфигурация Nginx
- [ ] Создан systemd service (для Puma)
- [ ] Подготовлен сервер (директории, пользователь)
- [ ] Выполнен первый деплой
- [ ] Протестированы все endpoints
- [ ] Остановлен Kamal (после успешного деплоя)

---

## 🔧 Полезные команды

```bash
# Проверить статус Passenger
sudo passenger-status
sudo passenger-memory-stats

# Проверить статус Puma
sudo systemctl status ikea_api

# Логи Rails
tail -f /var/www/ikea_api/current/log/production.log

# Логи Nginx
sudo tail -f /var/log/nginx/ikea_api_error.log
```

---

## ⚠️ Важные замечания

1. **Не останавливайте Kamal** до полного перехода на новую архитектуру
2. **Протестируйте все endpoints** перед финальным переключением
3. **Сделайте backup** базы данных перед миграцией
4. **Настройте мониторинг** для нового деплоя

