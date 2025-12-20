# 🚀 Деплой через Capistrano

## 📋 Обзор

Миграция с Kamal на классический деплой:
- **Nginx** на сервере (уже работает)
- **Puma** для Rails приложения
- **Capistrano** для деплоя

---

## 🎯 Шаг 1: Подготовка сервера

### 1.1. Запустить скрипт подготовки

```bash
./scripts/setup_server_for_capistrano.sh
```

Скрипт проверит:
- ✅ Наличие Ruby 3.3.0 (через rbenv)
- ✅ PostgreSQL клиент
- ✅ Redis
- ✅ Node.js
- ✅ Создаст необходимые директории
- ✅ Создаст systemd service для Puma

### 1.2. Настроить secrets на сервере

```bash
# Скопировать master.key
scp config/master.key deploy@45.135.234.22:/var/www/ikea_api/shared/config/

# Создать .env файл
ssh deploy@45.135.234.22
nano /var/www/ikea_api/shared/.env
```

Добавьте в `.env`:
```bash
RAILS_ENV=production
RAILS_MASTER_KEY=<ваш ключ>
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=ikea_api
DB_PASSWORD=<пароль>
REDIS_URL=redis://localhost:6379/0
MONGODB_URI=mongodb://localhost:27017/ikea
JWT_SECRET=<секрет>
```

### 1.3. Проверить SSH доступ к GitHub

```bash
ssh deploy@45.135.234.22 'ssh -T git@github.com'
```

Если нужно, добавьте SSH ключ:
```bash
ssh deploy@45.135.234.22
cat ~/.ssh/id_rsa.pub
# Добавьте этот ключ в GitHub Settings > SSH and GPG keys
```

---

## 🎯 Шаг 2: Первый деплой

### 2.1. Проверить конфигурацию Capistrano

```bash
cap production deploy:check
```

### 2.2. Выполнить деплой

```bash
cap production deploy
```

### 2.3. После успешного деплоя

```bash
# Включить и запустить Puma service
ssh deploy@45.135.234.22
sudo systemctl enable ikea_api
sudo systemctl start ikea_api
sudo systemctl status ikea_api
```

---

## 🎯 Шаг 3: Обновление Nginx

### 3.1. Скопировать новую конфигурацию

```bash
scp config/nginx/ikea_api_capistrano.conf deploy@45.135.234.22:/tmp/
ssh deploy@45.135.234.22
sudo mv /tmp/ikea_api_capistrano.conf /etc/nginx/sites-available/ikea_api
sudo nginx -t
sudo systemctl reload nginx
```

### 3.2. Проверить работу

```bash
# Проверить API
curl http://45.135.234.22/api/v1/products

# Проверить админку
curl http://45.135.234.22/admin

# Проверить Swagger
curl http://45.135.234.22/api-docs/index.html
```

---

## 🎯 Шаг 4: Остановка Kamal (после успешного тестирования)

### 4.1. Остановить Kamal контейнеры

```bash
# На сервере
docker ps | grep ikea_api
docker stop <container_id>
```

### 4.2. Остановить kamal-proxy (если нужно)

```bash
docker stop kamal-proxy
```

### 4.3. Удалить старые контейнеры (опционально)

```bash
docker ps -a | grep ikea_api
docker rm <container_id>
```

---

## 📋 Полезные команды Capistrano

```bash
# Проверить конфигурацию
cap production deploy:check

# Деплой
cap production deploy

# Откат к предыдущему релизу
cap production deploy:rollback

# Перезапуск Puma
cap production puma:restart

# Проверить статус
cap production puma:status

# Логи
cap production deploy:log_revision
```

---

## 🔧 Управление Puma

```bash
# Статус
sudo systemctl status ikea_api

# Перезапуск
sudo systemctl restart ikea_api

# Логи
sudo journalctl -u ikea_api -f
```

---

## 📋 Структура деплоя

```
/var/www/ikea_api/
├── current/          # Симлинк на текущий релиз
├── releases/         # История релизов
│   ├── 20231220120000/
│   ├── 20231220130000/
│   └── ...
└── shared/           # Общие файлы между релизами
    ├── config/
    │   ├── master.key
    │   └── .env
    ├── log/
    ├── tmp/
    │   ├── sockets/
    │   │   └── puma.sock
    │   └── pids/
    │       ├── puma.pid
    │       └── puma.state
    └── storage/
```

---

## ⚠️ Важные замечания

1. **Не останавливайте Kamal** до полного перехода на новую архитектуру
2. **Протестируйте все endpoints** перед финальным переключением
3. **Сделайте backup** базы данных перед миграцией
4. **Проверьте логи** после деплоя:
   ```bash
   tail -f /var/www/ikea_api/current/log/production.log
   sudo tail -f /var/log/nginx/ikea_api_error.log
   ```

---

## 🐛 Troubleshooting

### Puma не запускается

```bash
# Проверить логи
sudo journalctl -u ikea_api -n 50

# Проверить права на socket
ls -la /var/www/ikea_api/shared/tmp/sockets/

# Проверить конфигурацию
cat /var/www/ikea_api/current/config/puma.rb
```

### Nginx не может подключиться к Puma

```bash
# Проверить что socket существует
ls -la /var/www/ikea_api/shared/tmp/sockets/puma.sock

# Проверить права
sudo chown deploy:deploy /var/www/ikea_api/shared/tmp/sockets/puma.sock
sudo chmod 755 /var/www/ikea_api/shared/tmp/sockets/puma.sock
```

### Ошибки при деплое

```bash
# Проверить SSH доступ
ssh deploy@45.135.234.22

# Проверить Git доступ
ssh deploy@45.135.234.22 'ssh -T git@github.com'

# Проверить права на директорию
ls -la /var/www/ikea_api
```

