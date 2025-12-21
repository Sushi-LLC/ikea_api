#!/bin/bash
# Скрипт для восстановления конфигурации Nginx ikea-parser

set -e

SERVER="deploy@45.135.234.22"

echo "📋 Восстановление конфигурации Nginx ikea-parser..."

ssh "$SERVER" << 'EOF'
# Создаем правильную структуру upstream блоков
sudo bash << 'SUDOEOF'
# Сохраняем начало файла (комментарии до upstream)
head -1 /etc/nginx/sites-available/ikea-parser > /tmp/ikea-parser-new.conf

# Добавляем правильные upstream блоки
cat >> /tmp/ikea-parser-new.conf << 'UPSTREAMEOF'
# Upstream для Rails API (через Docker)
upstream rails_api {
  server 172.18.0.7:80;
  keepalive 64;
}

# Upstream для парсера (Node.js)
upstream ikea_parser_api {
  server localhost:3004;
  keepalive 64;
}

# Upstream для фронтенда (если используется)
upstream ikea_front {
  server localhost:3000;
  keepalive 64;
}
UPSTREAMEOF

# Находим начало server блока и добавляем остальную часть файла
awk '/^server {/,0' /etc/nginx/sites-available/ikea-parser >> /tmp/ikea-parser-new.conf

# Заменяем оригинальный файл
mv /tmp/ikea-parser-new.conf /etc/nginx/sites-available/ikea-parser

# Проверяем конфигурацию
echo "🔍 Проверка конфигурации Nginx..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Конфигурация валидна"
    echo "🔄 Перезагрузка Nginx..."
    systemctl reload nginx
    echo "✅ Nginx перезагружен"
else
    echo "❌ Ошибка в конфигурации Nginx!"
    exit 1
fi
SUDOEOF
EOF

echo ""
echo "✅ Конфигурация Nginx восстановлена!"

