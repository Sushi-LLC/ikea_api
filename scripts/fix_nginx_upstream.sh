#!/bin/bash
# Скрипт для исправления конфигурации Nginx - добавление upstream ikea_front

set -e

SERVER="deploy@45.135.234.22"
CONFIG_FILE="/etc/nginx/sites-available/ikea-parser"

echo "📋 Исправление конфигурации Nginx..."

ssh "$SERVER" << 'EOF'
# Добавляем upstream после определения ikea_parser_api
# Используем более простой подход - добавляем после закрывающей скобки ikea_parser_api
sudo bash -c 'cat >> /tmp/ikea_front_upstream.txt << UPSTREAMEOF

# Upstream для фронтенда (если используется)
upstream ikea_front {
  server localhost:3000;
  keepalive 64;
}
UPSTREAMEOF
'

# Находим строку с закрывающей скобкой ikea_parser_api и добавляем после неё
sudo awk '/^upstream ikea_parser_api {/,/^}/ {print; if (/^}/) {while ((getline line < "/tmp/ikea_front_upstream.txt") > 0) print line; close("/tmp/ikea_front_upstream.txt")}; next} 1' /etc/nginx/sites-available/ikea-parser > /tmp/ikea-parser-new.conf
sudo mv /tmp/ikea-parser-new.conf /etc/nginx/sites-available/ikea-parser
sudo rm -f /tmp/ikea_front_upstream.txt

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
echo "✅ Конфигурация Nginx исправлена!"

