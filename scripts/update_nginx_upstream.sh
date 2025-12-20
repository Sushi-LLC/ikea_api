#!/bin/bash
# Скрипт для настройки kamal-proxy на порт 8080 и обновления Nginx
# Запускать после каждого kamal deploy

echo "🔧 Настройка kamal-proxy на порт 8080..."

# Настраиваем kamal-proxy на порт 8080 (вместо 80, который занят Nginx)
ssh deploy@45.135.234.22 "mkdir -p .kamal/proxy && cat > .kamal/proxy/options << 'EOF'
--publish 8080:80 --publish 8443:443 --log-opt max-size=10m
EOF"

if [ $? -eq 0 ]; then
    echo "✅ Конфигурация kamal-proxy обновлена на порт 8080"
else
    echo "❌ Ошибка при обновлении конфигурации kamal-proxy"
    exit 1
fi

# Обновляем конфигурацию Nginx для проксирования к kamal-proxy:8080
echo "🔧 Обновление конфигурации Nginx..."

ssh deploy@45.135.234.22 "sudo sed -i 's/server [0-9.]*:[0-9]*;/server 127.0.0.1:8080;/' /etc/nginx/sites-available/ikea_api && sudo nginx -t && sudo systemctl reload nginx"

if [ $? -eq 0 ]; then
    echo "✅ Конфигурация Nginx обновлена успешно"
    echo ""
    echo "📋 Текущая архитектура:"
    echo "   Клиент → Nginx:80 → kamal-proxy:8080 → Rails:3000"
else
    echo "❌ Ошибка при обновлении конфигурации Nginx"
    exit 1
fi

