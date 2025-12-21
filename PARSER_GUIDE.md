# Руководство по использованию парсера IKEA

## Обзор

Парсер IKEA полностью переписан на Ruby on Rails и работает с PostgreSQL. Все задачи выполняются в фоновых процессах через Sidekiq.

## Возможности

1. **Ручной запуск/стоп задач** через админ-панель с указанием ограничений количества записей
2. **Настройка cron расписаний** через админ-панель
3. **Telegram уведомления** о старте/окончании парсинга
4. **Фоновая обработка** всех задач через Sidekiq
5. **Прямая запись в PostgreSQL** (MongoDB полностью исключен)

## Типы задач парсинга

- **categories** - Загрузка/обновление категорий
- **products** - Загрузка/обновление продуктовых позиций
- **bestsellers** - Загрузка/обновление хитов продаж
- **popular_categories** - Загрузка/обновление популярных категорий
- **category_images** - Загрузка/обновление картинок для категорий
- **product_images** - Загрузка/обновление картинок для продуктов

## Использование через админ-панель

### Запуск задач вручную

1. Перейдите в админ-панель: `http://your-domain/admin/parser_control`
2. Выберите тип задачи из выпадающего списка
3. Укажите лимит записей (необязательно, оставьте пустым для без ограничений)
4. Нажмите "Запустить"

### Остановка задач

1. В разделе "Активные задачи" найдите нужную задачу
2. Нажмите "Остановить"

### Настройка cron расписаний

1. Перейдите в раздел "Cron расписания"
2. Создайте новое расписание или отредактируйте существующее
3. Укажите:
   - Тип задачи
   - Cron выражение (например, `0 2 * * *` для ежедневного запуска в 2:00)
   - Включено/выключено
4. Нажмите "Синхронизировать" для применения изменений

### Просмотр истории задач

1. Перейдите в раздел "Задачи парсинга"
2. Просмотрите список всех выполненных задач с детальной статистикой

## Использование через Rake задачи

```bash
# Парсинг категорий
rails parser:parse_categories[1000]

# Парсинг продуктов
rails parser:parse_products[5000]

# Парсинг хитов продаж
rails parser:parse_bestsellers[500]

# Парсинг популярных категорий
rails parser:parse_popular_categories

# Загрузка изображений категорий
rails parser:download_category_images[100]

# Загрузка изображений продуктов
rails parser:download_product_images[1000]

# Синхронизация cron расписаний
rails parser:sync_cron
```

## Переменные окружения

Добавьте в `.env`:

```bash
# Telegram уведомления
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id

# Прокси серверы (через запятую)
PROXY_LIST=http://user:pass@proxy1:port,http://user:pass@proxy2:port

# IKEA API настройки
IKEA_ZIP=01-106
IKEA_STORE=307
IKEA_CLIENT_ID=your_client_id

# Redis для Sidekiq
REDIS_URL=redis://localhost:6379/0
```

## Запуск Sidekiq

Для работы фоновых задач необходимо запустить Sidekiq:

```bash
bundle exec sidekiq
```

Или через systemd (см. `config/puma.service` для примера).

## Структура файлов

```
app/
├── services/
│   ├── ikea_api_service.rb      # Работа с API IKEA
│   ├── proxy_rotator.rb          # Ротация прокси
│   ├── image_downloader.rb      # Загрузка изображений
│   ├── telegram_service.rb      # Telegram уведомления
│   └── cron_manager_service.rb  # Управление cron
├── jobs/
│   ├── parse_categories_job.rb
│   ├── parse_products_job.rb
│   ├── parse_bestsellers_job.rb
│   ├── parse_popular_categories_job.rb
│   ├── download_category_images_job.rb
│   └── download_product_images_job.rb
├── models/
│   ├── parser_task.rb           # Модель для задач парсинга
│   └── cron_schedule.rb         # Модель для cron расписаний
└── admin/
    ├── parser_control_admin.rb  # Панель управления парсером
    ├── parser_tasks_admin.rb    # История задач
    └── cron_schedules_admin.rb  # Управление cron
```

## Миграции

Выполните миграции для создания таблиц:

```bash
rails db:migrate
```

## Примечания

- Все задачи выполняются в фоновых процессах через Sidekiq
- MongoDB полностью исключен из проекта
- Все данные записываются напрямую в PostgreSQL
- Telegram уведомления отправляются автоматически при старте и завершении задач
- Cron расписания синхронизируются автоматически при старте приложения


