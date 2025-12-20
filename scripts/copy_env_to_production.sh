#!/bin/bash
# Скрипт для копирования переменных окружения на продакшн сервер

set -e

SERVER="deploy@45.135.234.22"
SECRETS_FILE=".kamal/secrets"
ENV_FILE="/var/www/ikea_api/shared/.env"

echo "📋 Копирование переменных окружения на продакшн..."

# Проверка наличия файла с секретами
if [ ! -f "$SECRETS_FILE" ]; then
    echo "❌ Файл $SECRETS_FILE не найден!"
    exit 1
fi

# Чтение секретов из файла
source "$SECRETS_FILE"

# Создание .env файла на сервере
echo "📝 Создание .env файла на сервере..."
ssh $SERVER << EOF
cat > $ENV_FILE << 'ENVEOF'
# Rails Environment
RAILS_ENV=production

# Rails Master Key
RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}

# Redis Configuration
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=${REDIS_PASSWORD}

# MongoDB Configuration
MONGODB_URI=mongodb://localhost:27017/ikea

# JWT Secret
JWT_SECRET=${JWT_SECRET}

# Puma Configuration (опционально)
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=1
RAILS_LOG_LEVEL=info
ENVEOF

# Установить правильные права доступа
chmod 600 $ENV_FILE
chown deploy:deploy $ENV_FILE

echo "✅ .env файл создан: $ENV_FILE"
echo ""
echo "📋 Содержимое файла:"
cat $ENV_FILE | sed 's/PASSWORD=.*/PASSWORD=***/' | sed 's/SECRET=.*/SECRET=***/' | sed 's/MASTER_KEY=.*/MASTER_KEY=***/'
EOF

echo ""
echo "✅ Переменные окружения скопированы на сервер!"
echo ""
echo "📋 Файл создан: $ENV_FILE"
echo ""
echo "⚠️  ВАЖНО: Проверьте что все переменные корректны!"
echo "   ssh $SERVER 'cat $ENV_FILE'"

