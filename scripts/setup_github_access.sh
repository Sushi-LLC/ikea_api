#!/bin/bash
# Скрипт для настройки доступа к GitHub репозиторию на сервере
# Использование: ./scripts/setup_github_access.sh

set -e

SERVER_IP="45.135.234.22"
DEPLOY_USER="deploy"
GITHUB_REPO="https://github.com/dmitryS1666/ikea_api.git"

echo "🔐 Настройка доступа к GitHub репозиторию на сервере..."

# Функция для выполнения команд на сервере
ssh_exec() {
    ssh "$DEPLOY_USER@$SERVER_IP" "$@"
}

echo "📦 Установка Git на сервере (если еще не установлен)..."
ssh_exec "sudo apt-get update && sudo apt-get install -y git"

echo "🔑 Проверка SSH ключей на сервере..."
if ssh_exec "test -f ~/.ssh/id_ed25519.pub"; then
    echo "✅ SSH ключ уже существует на сервере"
    echo ""
    echo "📋 Публичный ключ для добавления в GitHub:"
    ssh_exec "cat ~/.ssh/id_ed25519.pub"
else
    echo "🔑 Генерация SSH ключа на сервере..."
    ssh_exec "ssh-keygen -t ed25519 -C 'deploy@ikea_api' -f ~/.ssh/id_ed25519 -N ''"
    echo "✅ SSH ключ создан"
    echo ""
    echo "📋 Публичный ключ для добавления в GitHub:"
    ssh_exec "cat ~/.ssh/id_ed25519.pub"
fi

echo ""
echo "🌐 Добавление GitHub в known_hosts..."
ssh_exec "mkdir -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null && chmod 600 ~/.ssh/known_hosts"
echo "✅ GitHub добавлен в known_hosts"

echo ""
echo "📝 Следующие шаги:"
echo ""
echo "1. Скопируйте публичный ключ выше"
echo ""
echo "2. Добавьте его в GitHub:"
echo "   - Перейдите: https://github.com/settings/keys"
echo "   - Нажмите 'New SSH key'"
echo "   - Вставьте скопированный ключ"
echo "   - Сохраните"
echo ""
echo "3. После добавления ключа в GitHub, проверьте доступ:"
echo "   ssh deploy@$SERVER_IP 'ssh -T git@github.com'"
echo "   Должно вернуть: Hi dmitryS1666! You've successfully authenticated..."
echo ""
echo "4. После настройки ключа Kamal сможет клонировать репозиторий:"
echo "   kamal deploy"

