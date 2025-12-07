#!/bin/bash
# Скрипт для первоначальной настройки сервера для Kamal
# Использование: ./scripts/setup_server.sh

set -e

SERVER_IP="45.135.234.22"
SERVER_USER="root"
SERVER_PASSWORD="f8RpYS53tYgLPwnk"
DEPLOY_USER="deploy"
APP_DIR="/home/deploy/apps/ikea_back"

echo "🚀 Настройка сервера для деплоя через Kamal..."

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$@"
}

echo "📦 Установка необходимых пакетов на сервере..."
ssh_exec "apt-get update && apt-get install -y \
    curl \
    git \
    docker.io \
    docker-compose \
    && systemctl enable docker \
    && systemctl start docker"

echo "👤 Создание пользователя deploy..."
ssh_exec "useradd -m -s /bin/bash deploy || true"
ssh_exec "usermod -aG sudo deploy"
ssh_exec "usermod -aG docker deploy"

echo "📁 Создание директорий..."
ssh_exec "mkdir -p $APP_DIR"
ssh_exec "chown -R deploy:deploy /home/deploy/apps"

echo "🔐 Настройка SSH для пользователя deploy..."
ssh_exec "mkdir -p /home/deploy/.ssh"
ssh_exec "chmod 700 /home/deploy/.ssh"
ssh_exec "chown -R deploy:deploy /home/deploy/.ssh"

# Настройка sudo без пароля для deploy (для Kamal)
ssh_exec "echo 'deploy ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/deploy"
ssh_exec "chmod 0440 /etc/sudoers.d/deploy"

echo "✅ Сервер настроен!"
echo ""
echo "📝 Следующие шаги:"
echo "1. Добавьте ваш SSH ключ на сервер (пользователь deploy без пароля):"
echo "   cat ~/.ssh/id_ed25519.pub | ssh root@$SERVER_IP \\"
echo "     \"mkdir -p /home/deploy/.ssh && \\"
echo "      cat >> /home/deploy/.ssh/authorized_keys && \\"
echo "      chown -R deploy:deploy /home/deploy/.ssh && \\"
echo "      chmod 700 /home/deploy/.ssh && \\"
echo "      chmod 600 /home/deploy/.ssh/authorized_keys\""
echo "   Пароль для root: $SERVER_PASSWORD"
echo ""
echo "2. Или создайте новый SSH ключ:"
echo "   ssh-keygen -t ed25519 -C 'deploy@ikea_back'"
echo "   Затем выполните команду из пункта 1"
echo ""
echo "3. Проверьте подключение:"
echo "   ssh deploy@$SERVER_IP"
echo ""
echo "4. После настройки SSH ключа запустите:"
echo "   kamal setup"
echo "   kamal deploy"

