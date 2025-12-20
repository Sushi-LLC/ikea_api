#!/bin/bash
# Скрипт для исправления конфигурации Nginx для фронтенда

set -e

SERVER="deploy@45.135.234.22"
NGINX_CONFIG="/etc/nginx/sites-available/ikea_front.conf"

echo "🔧 Исправление конфигурации Nginx для фронтенда..."

# Создаем исправленную конфигурацию
cat << 'NGINX_CONFIG_EOF' | ssh $SERVER "sudo tee $NGINX_CONFIG" > /dev/null
# Nginx конфигурация для IKEYA Frontend
# Frontend работает на порту 3000 (Next.js)

upstream ikea_front {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    server_name 45.135.234.22;

    # Логи
    access_log /var/log/nginx/ikea_front_access.log;
    error_log /var/log/nginx/ikea_front_error.log;

    # Максимальный размер загружаемых файлов
    client_max_body_size 20M;

    # Проксирование на Next.js приложение
    # Next.js работает на корневом пути, поэтому используем rewrite для удаления префикса
    location /ikea_front/ {
        # Удаляем префикс /ikea_front перед проксированием
        rewrite ^/ikea_front/(.*) /$1 break;
        rewrite ^/ikea_front$ / break;
        
        proxy_pass http://ikea_front;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # Заголовки
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Отключаем буферизацию для streaming
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Редирект с /ikea_front на /ikea_front/
    location = /ikea_front {
        return 301 /ikea_front/;
    }

    # Статические файлы Next.js (_next/static) - должны быть ДО основного location
    location /ikea_front/_next/ {
        rewrite ^/ikea_front/_next/(.*) /_next/$1 break;
        proxy_pass http://ikea_front;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Кэширование статики
        proxy_cache_valid 200 60m;
        add_header Cache-Control "public, immutable";
    }

    # Статические файлы из public (assets) - должны быть ДО основного location
    location /ikea_front/assets/ {
        rewrite ^/ikea_front/assets/(.*) /assets/$1 break;
        proxy_pass http://ikea_front;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Кэширование статики
        proxy_cache_valid 200 60m;
        add_header Cache-Control "public, max-age=3600";
    }
}
NGINX_CONFIG_EOF

echo "✅ Конфигурация обновлена"

# Проверка конфигурации
echo "🔍 Проверка конфигурации Nginx..."
ssh $SERVER "sudo nginx -t" || {
    echo "❌ Ошибка в конфигурации Nginx"
    exit 1
}

# Перезагрузка Nginx
echo "🔄 Перезагрузка Nginx..."
ssh $SERVER "sudo systemctl reload nginx"
echo "✅ Nginx перезагружен"

# Проверка логов
echo "📋 Последние ошибки (если есть):"
ssh $SERVER "sudo tail -10 /var/log/nginx/ikea_front_error.log" || echo "Логи пусты"

echo ""
echo "✅ Готово! Проверьте: http://45.135.234.22/ikea_front/"

