#!/bin/bash
# Скрипт для проверки подключения к PostgreSQL

set -e

SERVER="deploy@45.135.234.22"

echo "🔍 Проверка подключения к PostgreSQL..."

ssh $SERVER << 'EOF'
# Загрузить переменные окружения
source /var/www/ikea_api/shared/.env

echo "📋 Параметры подключения:"
echo "  DB_HOST: $DB_HOST"
echo "  DB_PORT: $DB_PORT"
echo "  DB_USERNAME: $DB_USERNAME"
echo "  DB_NAME: ikea_api_production"
echo ""

# Проверка доступности порта
echo "🔍 Проверка доступности порта $DB_PORT..."
if nc -z localhost $DB_PORT 2>/dev/null; then
    echo "✅ Порт $DB_PORT доступен"
else
    echo "❌ Порт $DB_PORT недоступен"
    exit 1
fi

# Проверка подключения через TCP
echo "🔍 Проверка подключения через TCP..."
export PGPASSWORD="$DB_PASSWORD"
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d ikea_api_production -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Подключение к PostgreSQL успешно!"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d ikea_api_production -c "SELECT version();" | head -3
else
    echo "❌ Не удалось подключиться к PostgreSQL"
    echo "Проверьте:"
    echo "  1. Запущен ли Docker контейнер: docker ps | grep postgres"
    echo "  2. Правильность пароля в .env"
    echo "  3. Доступность порта: nc -z localhost $DB_PORT"
    exit 1
fi
EOF

echo ""
echo "✅ Проверка завершена!"

