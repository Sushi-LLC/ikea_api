#!/bin/bash
# Скрипт для обновления конфигурации Nginx на сервере

set -e

SERVER="deploy@45.135.234.22"
CONFIG_FILE="config/nginx/ikea_api.conf"
REMOTE_CONFIG="/etc/nginx/sites-available/ikea_api"

echo "📋 Обновление конфигурации Nginx на сервере..."

# Копируем конфигурацию на сервер
echo "📝 Копирование конфигурации..."
scp "$CONFIG_FILE" "$SERVER:/tmp/ikea_api.conf"

# Применяем конфигурацию на сервере
echo "🔧 Применение конфигурации..."
ssh "$SERVER" << 'EOF'
sudo cp /tmp/ikea_api.conf /etc/nginx/sites-available/ikea_api

# Проверяем конфигурацию
echo "🔍 Проверка конфигурации Nginx..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Конфигурация валидна"
    echo "🔄 Перезагрузка Nginx..."
    sudo systemctl reload nginx
    echo "✅ Nginx перезагружен"
else
    echo "❌ Ошибка в конфигурации Nginx!"
    exit 1
fi
EOF

echo ""
echo "✅ Конфигурация Nginx обновлена!"
echo ""
echo "📋 Проверьте, что статические файлы доступны:"
echo "   curl -I http://45.135.234.22/assets/trestle/admin-d5ae541eb4f1689b0a9ce549ffa17cb2dc25a0b8f8345f0e25d3d35d2320cd29.css"

