# 🚀 Деплой через Kamal

Инструкция по настройке и деплою приложения на сервер через Kamal (MRSK).

## 📋 Информация о сервере

- **IP**: 45.135.234.22
- **Пользователь root**: root / f8RpYS53tYgLPwnk
- **Пользователь deploy**: будет создан
- **Директория**: /home/deploy/apps/ikea_back

## 🔧 Шаг 1: Установка Kamal

```bash
# Установка Kamal
gem install kamal

# Проверка версии
kamal version
```

## 🖥️ Шаг 2: Настройка сервера

### Автоматическая настройка (рекомендуется)

```bash
# Установка sshpass (если еще не установлен)
sudo apt-get install sshpass

# Сделайте скрипт исполняемым
chmod +x scripts/setup_server.sh

# Запустите настройку сервера
./scripts/setup_server.sh
```

### Ручная настройка

```bash
# Подключение к серверу
ssh root@45.135.234.22
# Пароль: f8RpYS53tYgLPwnk

# Установка Docker
apt-get update
apt-get install -y docker.io docker-compose
systemctl enable docker
systemctl start docker

# Создание пользователя deploy
useradd -m -s /bin/bash deploy
usermod -aG sudo deploy
usermod -aG docker deploy

# Настройка sudo без пароля для deploy
echo 'deploy ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/deploy
chmod 0440 /etc/sudoers.d/deploy

# Создание директорий
mkdir -p /home/deploy/apps/ikea_back
chown -R deploy:deploy /home/deploy/apps
```

## 🔐 Шаг 3: Настройка SSH ключей

### На локальной машине

```bash
# Генерация SSH ключа (если еще нет)
ssh-keygen -t ed25519 -C "deploy@ikea_back"

# Копирование ключа на сервер
ssh-copy-id deploy@45.135.234.22

# Или вручную через root
cat ~/.ssh/id_ed25519.pub | ssh root@45.135.234.22 \
  "mkdir -p /home/deploy/.ssh && \
   cat >> /home/deploy/.ssh/authorized_keys && \
   chown -R deploy:deploy /home/deploy/.ssh && \
   chmod 700 /home/deploy/.ssh && \
   chmod 600 /home/deploy/.ssh/authorized_keys"
```

### Проверка подключения

```bash
ssh deploy@45.135.234.22
```

## 🔑 Шаг 4: Настройка доступа к GitHub

Kamal использует Git для получения актуального кода из репозитория. Нужно настроить доступ к GitHub на сервере.

### Автоматическая настройка

```bash
# Сделайте скрипт исполняемым
chmod +x scripts/setup_github_access.sh

# Запустите настройку
./scripts/setup_github_access.sh
```

Скрипт покажет публичный SSH ключ, который нужно добавить в GitHub.

### Ручная настройка

```bash
# Подключение к серверу
ssh deploy@45.135.234.22

# Генерация SSH ключа (если еще нет)
ssh-keygen -t ed25519 -C "deploy@ikea_api" -f ~/.ssh/id_ed25519 -N ""

# Просмотр публичного ключа
cat ~/.ssh/id_ed25519.pub
```

**Добавление ключа в GitHub:**

1. Скопируйте публичный ключ
2. Перейдите: https://github.com/settings/keys
3. Нажмите "New SSH key"
4. Вставьте ключ и сохраните

**Проверка доступа:**

```bash
ssh deploy@45.135.234.22 'ssh -T git@github.com'
# Должно вернуть: Hi dmitryS1666! You've successfully authenticated...
```

### Настройка Git на сервере

```bash
# На сервере
ssh deploy@45.135.234.22

# Настройка Git (если нужно)
git config --global user.name "Deploy User"
git config --global user.email "deploy@ikea_api"
```

## 🔑 Шаг 5: Настройка секретов Kamal

```bash
# Инициализация Kamal (создаст .kamal/secrets)
kamal setup

# Или создайте вручную
mkdir -p .kamal
```

Создайте файл `.kamal/secrets` с секретами:

```bash
cat > .kamal/secrets << EOF
RAILS_MASTER_KEY=$(rails secret)
DB_USERNAME=postgres
DB_PASSWORD=your_secure_password_here
REDIS_PASSWORD=
MONGODB_URI=mongodb://mongodb:27017/ikea
JWT_SECRET=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
POSTGRES_PASSWORD=your_secure_postgres_password_here
EOF

# Убедитесь, что файл не попадет в git
echo ".kamal/secrets" >> .gitignore
```

**Важно**: Файл `.kamal/secrets` содержит секретные данные и не должен попадать в git!

## 📝 Шаг 5: Проверка конфигурации

```bash
# Просмотр конфигурации
kamal config

# Проверка подключения к серверу
kamal app details
```

## 🚀 Шаг 6: Деплой приложения

### Первый деплой

```bash
# Деплой приложения
kamal deploy

# Деплой с дополнительными сервисами
kamal accessory boot all
```

### Деплой только приложения

```bash
kamal app deploy
```

### Деплой только сервисов (PostgreSQL, Redis, MongoDB)

```bash
kamal accessory boot postgres
kamal accessory boot redis
kamal accessory boot mongodb
```

## 🗄️ Шаг 8: Настройка базы данных

```bash
# Создание базы данных
kamal app exec "rails db:create"

# Применение миграций
kamal app exec "rails db:migrate"

# Загрузка начальных данных (если нужно)
kamal app exec "rails db:seed"
```

## 📊 Управление приложением

### Просмотр статуса

```bash
# Статус приложения
kamal app details

# Статус всех сервисов
kamal accessory details all
```

### Просмотр логов

```bash
# Логи приложения
kamal app logs

# Логи с отслеживанием
kamal app logs -f

# Логи PostgreSQL
kamal accessory logs postgres

# Логи Redis
kamal accessory logs redis

# Логи MongoDB
kamal accessory logs mongodb
```

### Rails консоль

```bash
kamal app exec "rails console"
```

### Выполнение команд

```bash
# Выполнение любой команды
kamal app exec "rails routes"
kamal app exec "rails db:migrate"
kamal app exec "bundle exec rake task:name"
```

### Перезапуск

```bash
# Перезапуск приложения
kamal app restart

# Перезапуск всех сервисов
kamal accessory restart all
```

### Остановка

```bash
# Остановка приложения
kamal app stop

# Остановка всех сервисов
kamal accessory stop all
```

## 🔄 Обновление приложения

```bash
# 1. Обновите код локально
git pull origin main

# 2. Деплой обновлений
kamal deploy

# 3. При необходимости выполните миграции
kamal app exec "rails db:migrate"
```

## 🛠️ Полезные команды

```bash
# Просмотр всех доступных команд
kamal help

# Просмотр конфигурации
kamal config

# Просмотр версии образа
kamal app version

# Очистка старых образов
kamal app prune

# Просмотр переменных окружения
kamal app exec "env"
```

## 🔍 Решение проблем

### Проблема: Ошибка подключения

```bash
# Проверка SSH подключения
ssh deploy@45.135.234.22

# Проверка прав доступа
kamal app details
```

### Проблема: Docker не запущен

```bash
# На сервере
ssh deploy@45.135.234.22
sudo systemctl status docker
sudo systemctl start docker
```

### Проблема: Ошибка при деплое

```bash
# Просмотр подробных логов
kamal deploy --verbose

# Проверка конфигурации
kamal config validate
```

### Проблема: База данных не доступна

```bash
# Проверка статуса PostgreSQL
kamal accessory details postgres

# Перезапуск PostgreSQL
kamal accessory restart postgres
```

## 🌐 Шаг 9: Настройка Nginx

Nginx будет работать как reverse proxy для API и отдавать статику фронтенда.

### Автоматическая настройка

```bash
# Сделайте скрипт исполняемым
chmod +x scripts/setup_nginx.sh

# Запустите настройку Nginx
./scripts/setup_nginx.sh
```

### Ручная настройка

```bash
# Подключение к серверу
ssh deploy@45.135.234.22

# Установка Nginx
sudo apt-get update
sudo apt-get install -y nginx

# Копирование конфигурации
# (скопируйте config/nginx/ikea_api.conf на сервер)
sudo cp config/nginx/ikea_api.conf /etc/nginx/sites-available/ikea_api
sudo ln -sf /etc/nginx/sites-available/ikea_api /etc/nginx/sites-enabled/ikea_api
sudo rm -f /etc/nginx/sites-enabled/default

# Создание директории для фронтенда
sudo mkdir -p /var/www/ikea_frontend/dist
sudo chown -R deploy:deploy /var/www/ikea_frontend

# Проверка и перезапуск
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### Размещение фронтенда

```bash
# На сервере
ssh deploy@45.135.234.22

# Разместите собранный фронтенд в директорию
# /var/www/ikea_frontend/dist
# Например, через rsync:
# rsync -avz dist/ deploy@45.135.234.22:/var/www/ikea_frontend/dist/
```

### Настройка домена (в будущем)

```bash
# 1. Обновите server_name в конфигурации
sudo nano /etc/nginx/sites-available/ikea_api
# Измените: server_name 45.135.234.22; на server_name your-domain.com;

# 2. Настройте SSL через certbot
sudo certbot --nginx -d your-domain.com

# 3. Перезапустите Nginx
sudo systemctl reload nginx
```

### Проверка работы

```bash
# Health check API
curl http://45.135.234.22/up

# API endpoints
curl http://45.135.234.22/api/v1/products

# Frontend
curl http://45.135.234.22/
```

## 🔒 Безопасность

1. **Храните секреты в безопасности**:
   - Файл `.kamal/secrets` не должен попадать в git
   - Используйте сильные пароли
   - Регулярно обновляйте секреты

2. **Настройте firewall**:
   ```bash
   # На сервере
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

3. **Регулярные обновления**:
   ```bash
   # На сервере
   sudo apt-get update && sudo apt-get upgrade
   ```

4. **Ограничение доступа к портам**:
   - Порт 3000 (Rails) доступен только через Nginx (localhost)
   - Порт 5432 (PostgreSQL) не открыт наружу
   - Порт 6379 (Redis) не открыт наружу
   - Порт 27017 (MongoDB) не открыт наружу

## 📚 Дополнительные ресурсы

- [Kamal Documentation](https://kamal-deploy.org)
- [Kamal GitHub](https://github.com/basecamp/kamal)

---

**Готово! Приложение развернуто через Kamal.** 🎉

