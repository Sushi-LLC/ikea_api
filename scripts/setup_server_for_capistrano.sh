#!/bin/bash
# Скрипт для подготовки сервера к деплою через Capistrano

set -e

SERVER="deploy@45.135.234.22"

echo "🚀 Подготовка сервера для Capistrano деплоя..."

# 1. Проверка и создание директорий
echo "📁 Создание директорий..."
ssh $SERVER << 'EOF'
sudo mkdir -p /var/www/ikea_api
sudo chown deploy:deploy /var/www/ikea_api
mkdir -p /var/www/ikea_api/shared/config
mkdir -p /var/www/ikea_api/shared/tmp/sockets
mkdir -p /var/www/ikea_api/shared/tmp/pids
mkdir -p /var/www/ikea_api/shared/tmp/cache
mkdir -p /var/www/ikea_api/shared/log
mkdir -p /var/www/ikea_api/shared/storage
EOF

# 2. Установка зависимостей для компиляции Ruby
echo "📦 Установка зависимостей для Ruby..."
ssh $SERVER << 'EOF'
# Установить необходимые пакеты для компиляции Ruby
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential \
    libssl-dev \
    libyaml-dev \
    libreadline-dev \
    zlib1g-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm-dev \
    libdb-dev \
    libbz2-dev \
    liblzma-dev \
    autoconf \
    bison \
    git
echo "✅ Зависимости установлены"
EOF

# 3. Проверка и установка Ruby через asdf
echo "🔍 Проверка Ruby и asdf..."
ssh $SERVER << 'EOF'
# Проверка и установка asdf
if [ ! -d "$HOME/.asdf" ]; then
    echo "📦 Установка asdf..."
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    
    # Добавить в .bashrc если еще не добавлено
    if ! grep -q "asdf.sh" ~/.bashrc; then
        echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc
        echo '. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
    fi
    
    # Загрузить asdf в текущую сессию
    . "$HOME/.asdf/asdf.sh"
    echo "✅ asdf установлен"
else
    # Загрузить asdf в текущую сессию
    . "$HOME/.asdf/asdf.sh"
    echo "✅ asdf уже установлен"
fi

# Проверка и установка плагина Ruby
if ! asdf plugin list | grep -q "ruby"; then
    echo "📦 Установка плагина Ruby для asdf..."
    asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
    echo "✅ Плагин Ruby установлен"
else
    echo "✅ Плагин Ruby уже установлен"
fi

# Проверка и установка Ruby 3.3.0
if ! asdf list ruby | grep -q "3.3.0"; then
    echo "📦 Установка Ruby 3.3.0 (это может занять несколько минут)..."
    # Установить Ruby с необходимыми опциями
    RUBY_CONFIGURE_OPTS="--enable-shared --with-openssl-dir=/usr" asdf install ruby 3.3.0
    
    if [ $? -eq 0 ]; then
        echo "✅ Ruby 3.3.0 установлен"
    else
        echo "❌ Ошибка установки Ruby. Проверьте логи выше."
        exit 1
    fi
else
    echo "✅ Ruby 3.3.0 уже установлен"
fi

# Установить версию Ruby глобально
asdf global ruby 3.3.0

# Загрузить asdf еще раз для применения изменений
. "$HOME/.asdf/asdf.sh"

# Проверить установку
RUBY_VERSION=$(asdf current ruby 2>/dev/null | awk '{print $2}' || echo "")
if [ -z "$RUBY_VERSION" ]; then
    echo "⚠️  Не удалось определить версию Ruby"
    exit 1
fi
echo "✅ Ruby версия: $RUBY_VERSION"

# Проверить что Ruby доступен
if ! command -v ruby &> /dev/null; then
    echo "⚠️  Ruby не найден в PATH. Попытка перезагрузки asdf..."
    . "$HOME/.asdf/asdf.sh"
    if ! command -v ruby &> /dev/null; then
        echo "❌ Ruby все еще не найден. Проверьте установку вручную."
        exit 1
    fi
fi

echo "✅ Ruby доступен: $(ruby --version)"
EOF

# 4. Проверка и установка PostgreSQL (как системный сервис)
echo "🔍 Проверка PostgreSQL..."
ssh $SERVER << 'EOF'
if ! systemctl is-active --quiet postgresql 2>/dev/null; then
    echo "📦 Установка PostgreSQL как системного сервиса..."
    sudo apt-get update -qq
    sudo apt-get install -y postgresql postgresql-contrib libpq-dev
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    echo "✅ PostgreSQL установлен и запущен"
else
    echo "✅ PostgreSQL уже установлен и запущен"
fi
EOF

# 5. Проверка и установка Redis
echo "🔍 Проверка Redis..."
ssh $SERVER << 'EOF'
if ! command -v redis-cli &> /dev/null; then
    echo "📦 Установка Redis..."
    sudo apt-get update -qq
    sudo apt-get install -y redis-server
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    echo "✅ Redis установлен и запущен"
else
    echo "✅ Redis уже установлен"
    # Убедиться что Redis запущен
    if ! sudo systemctl is-active --quiet redis-server; then
        sudo systemctl start redis-server
        echo "✅ Redis запущен"
    fi
fi
EOF

# 6. Проверка и установка Node.js (для asset pipeline)
echo "🔍 Проверка Node.js..."
ssh $SERVER << 'EOF'
if ! command -v node &> /dev/null; then
    echo "📦 Установка Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo "✅ Node.js установлен: $(node --version)"
else
    echo "✅ Node.js уже установлен: $(node --version)"
fi
EOF

# 7. Создание systemd service для Puma
echo "⚙️  Создание systemd service для Puma..."
cat config/puma.service | ssh $SERVER "sudo tee /etc/systemd/system/ikea_api.service" > /dev/null
ssh $SERVER "sudo systemctl daemon-reload"
echo "✅ Systemd service создан (но не запущен, будет запущен после первого деплоя)"

# 8. Инструкции по настройке secrets
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Скопируйте config/master.key на сервер:"
echo "   scp config/master.key $SERVER:/var/www/ikea_api/shared/config/"
echo ""
echo "2. Создайте .env файл на сервере:"
echo "   ssh $SERVER"
echo "   nano /var/www/ikea_api/shared/.env"
echo "   # Добавьте необходимые переменные окружения"
echo ""
echo "3. Проверьте SSH доступ к GitHub:"
echo "   ssh $SERVER 'ssh -T git@github.com'"
echo ""
echo "4. Выполните первый деплой:"
echo "   cap production deploy"
echo ""
echo "✅ Подготовка сервера завершена!"

