#!/bin/bash
# Скрипт для остановки Docker контейнеров (миграция с Docker на системные сервисы)

set -e

SERVER="deploy@45.135.234.22"

echo "🛑 Остановка Docker контейнеров..."

ssh $SERVER << 'EOF'
# Остановить PostgreSQL контейнер
if docker ps | grep -q "ikea_api-postgres"; then
    echo "🛑 Остановка PostgreSQL контейнера..."
    docker stop ikea_api-postgres
    echo "✅ PostgreSQL контейнер остановлен"
else
    echo "ℹ️  PostgreSQL контейнер не запущен"
fi

# Остановить Redis контейнер
if docker ps | grep -q "ikea_api-redis"; then
    echo "🛑 Остановка Redis контейнера..."
    docker stop ikea_api-redis
    echo "✅ Redis контейнер остановлен"
else
    echo "ℹ️  Redis контейнер не запущен"
fi

# Остановить MongoDB контейнер (если есть)
if docker ps | grep -q "ikea_api-mongodb"; then
    echo "🛑 Остановка MongoDB контейнера..."
    docker stop ikea_api-mongodb
    echo "✅ MongoDB контейнер остановлен"
else
    echo "ℹ️  MongoDB контейнер не запущен"
fi

echo ""
echo "✅ Docker контейнеры остановлены"
echo ""
echo "📋 Следующий шаг:"
echo "  ./scripts/setup_postgresql_service.sh"
EOF

