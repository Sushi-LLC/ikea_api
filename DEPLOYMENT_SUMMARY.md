# 📋 Краткая сводка по деплою

## 🎯 Очередность действий

### 1️⃣ Настройка продакшн-сервера (один раз)

**Все команды выполняются на локальной машине:**

```
1. Настройка сервера (Docker, пользователь deploy)
   → ./scripts/setup_server.sh
   (скрипт сам подключается к серверу через SSH)

2. Настройка SSH ключей для пользователя deploy
   → cat ~/.ssh/id_ed25519.pub | ssh root@45.135.234.22 "..."
   (добавляет ваш SSH ключ через root, т.к. deploy без пароля)

3. Настройка доступа к GitHub
   → ./scripts/setup_github_access.sh
   (скрипт подключается к серверу и показывает ключ для GitHub)

4. Настройка Nginx
   → ./scripts/setup_nginx.sh
   (скрипт подключается к серверу и настраивает Nginx)
```

### 2️⃣ Деплой приложения

```
1. Подготовка секретов
   → .kamal/secrets

2. Установка Kamal
   → gem install kamal

3. Деплой
   → kamal deploy

4. Настройка БД (только первый раз)
   → kamal app exec "rails db:create db:migrate db:seed"
```

### 3️⃣ Обновление приложения

```
1. git pull origin main
2. kamal deploy
3. kamal app exec "rails db:migrate" (если есть миграции)
```

---

## 📚 Подробные инструкции

- **DEPLOYMENT_GUIDE.md** - Полное руководство с пошаговыми инструкциями
- **DEPLOY_KAMAL.md** - Детальная документация по Kamal
- **NGINX_SETUP.md** - Настройка Nginx

---

## ⚡ Быстрая команда для первого деплоя

**Все команды выполняются на локальной машине в директории проекта:**

```bash
# 1. Установка sshpass (если нужно)
sudo apt-get install sshpass  # Ubuntu/Debian

# 2. Настройка сервера (скрипт сам подключится к серверу)
chmod +x scripts/setup_server.sh
./scripts/setup_server.sh

# 3. Настройка SSH ключей для пользователя deploy
ssh-copy-id deploy@45.135.234.22

# 4. Настройка доступа к GitHub (добавьте показанный ключ в GitHub)
chmod +x scripts/setup_github_access.sh
./scripts/setup_github_access.sh

# 5. Настройка Nginx
chmod +x scripts/setup_nginx.sh
./scripts/setup_nginx.sh

# 2. Подготовка секретов
mkdir -p .kamal
cat > .kamal/secrets << EOF
RAILS_MASTER_KEY=$(rails secret)
DB_USERNAME=postgres
DB_PASSWORD=your_password
REDIS_PASSWORD=
JWT_SECRET=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
POSTGRES_PASSWORD=your_postgres_password
EOF

# 3. Деплой
gem install kamal
kamal deploy
kamal app exec "rails db:create db:migrate db:seed"
```
