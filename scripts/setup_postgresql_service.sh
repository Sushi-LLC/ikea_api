#!/bin/bash
# Скрипт для установки и настройки PostgreSQL как системного сервиса

set -e

SERVER="deploy@45.135.234.22"

echo "🐘 Установка PostgreSQL как системного сервиса..."

ssh $SERVER << 'EOF'
# 1. Установка PostgreSQL
echo "📦 Установка PostgreSQL..."
sudo apt-get update -qq
sudo apt-get install -y postgresql postgresql-contrib libpq-dev

# 2. Запуск и включение сервиса
echo "🚀 Запуск PostgreSQL сервиса..."
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo systemctl status postgresql --no-pager | head -5

# 3. Проверка версии
echo "✅ PostgreSQL установлен:"
psql --version

# 4. Создание базы данных и пользователя
echo "📋 Настройка базы данных..."

# Загрузить переменные окружения
if [ -f /var/www/ikea_api/shared/.env ]; then
    source /var/www/ikea_api/shared/.env
else
    echo "⚠️  Файл .env не найден. Используем значения по умолчанию."
    DB_USERNAME=${DB_USERNAME:-postgres}
    DB_PASSWORD=${DB_PASSWORD:-postgres}
fi

# Создать пользователя и базу данных
sudo -u postgres psql << PSQLEOF
-- Создать пользователя если не существует
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USERNAME') THEN
    CREATE USER $DB_USERNAME WITH PASSWORD '$DB_PASSWORD';
    RAISE NOTICE 'Пользователь $DB_USERNAME создан';
  ELSE
    ALTER USER $DB_USERNAME WITH PASSWORD '$DB_PASSWORD';
    RAISE NOTICE 'Пароль пользователя $DB_USERNAME обновлен';
  END IF;
END
\$\$;

-- Создать базу данных если не существует
SELECT 'CREATE DATABASE ikea_api_production'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ikea_api_production')\gexec

-- Выдать права на базу данных
GRANT ALL PRIVILEGES ON DATABASE ikea_api_production TO $DB_USERNAME;

\q
PSQLEOF

# Подключиться к базе и выдать права на схему
echo "📋 Настройка прав на схему..."
sudo -u postgres psql -d ikea_api_production << PSQLEOF
GRANT ALL ON SCHEMA public TO $DB_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USERNAME;
\q
PSQLEOF

# 5. Настройка pg_hba.conf для доступа через localhost
echo "⚙️  Настройка доступа к PostgreSQL..."

# Определить версию PostgreSQL
PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version_num;" | xargs | cut -c1-2)
if [ -z "$PG_VERSION" ]; then
    # Fallback: определить из версии psql
    PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
fi

PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

if [ -f "$PG_HBA" ]; then
    # Создать backup
    sudo cp $PG_HBA ${PG_HBA}.backup
    
    # Проверить что localhost доступен (обычно уже настроен по умолчанию)
    if ! sudo grep -q "^host.*all.*all.*127.0.0.1/32.*md5" $PG_HBA; then
        echo "host    all             all             127.0.0.1/32            md5" | sudo tee -a $PG_HBA
    fi
    
    # Перезагрузить PostgreSQL
    sudo systemctl reload postgresql
    echo "✅ Конфигурация доступа обновлена"
else
    echo "⚠️  Файл $PG_HBA не найден. Проверьте установку PostgreSQL."
fi

# 6. Проверка подключения
echo "🔍 Проверка подключения..."
export PGPASSWORD="$DB_PASSWORD"
if psql -h localhost -U "$DB_USERNAME" -d ikea_api_production -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Подключение к базе данных успешно!"
    psql -h localhost -U "$DB_USERNAME" -d ikea_api_production -c "SELECT version();" | head -3
else
    echo "⚠️  Проверьте подключение вручную"
fi

echo ""
echo "✅ PostgreSQL настроен как системный сервис!"
echo ""
echo "📋 Информация:"
echo "  Версия: $(psql --version)"
echo "  База данных: ikea_api_production"
echo "  Пользователь: $DB_USERNAME"
echo "  Хост: localhost"
echo "  Порт: 5432"
EOF

echo ""
echo "✅ Установка завершена!"

