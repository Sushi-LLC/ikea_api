# Руководство по настройке

## Облачное хранилище изображений

### Локальное хранилище (по умолчанию)

Изображения сохраняются в `public/images/` на сервере.

**Настройка:**
```bash
# В .env файле (или не указывать, т.к. это значение по умолчанию)
IMAGE_STORAGE_TYPE=local
```

### Amazon S3

**Требования:**
- Gem `aws-sdk-s3` (добавить в Gemfile)
- AWS аккаунт с S3 bucket

**Настройка:**
```bash
# В .env файле
IMAGE_STORAGE_TYPE=s3
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_S3_BUCKET=your-bucket-name
```

**Установка gem:**
```ruby
# В Gemfile
gem 'aws-sdk-s3'
```

**Реализация:**
Файл `app/services/image_storage/s3.rb` содержит заготовку. Необходимо реализовать методы:
- `upload(image_url, product_sku:, category_id:)` - загрузка изображения
- `exists?(key)` - проверка существования
- `url(key)` - получение публичного URL
- `delete(key)` - удаление изображения

### Cloudinary

**Требования:**
- Gem `cloudinary` (добавить в Gemfile)
- Cloudinary аккаунт

**Настройка:**
```bash
# В .env файле
IMAGE_STORAGE_TYPE=cloudinary
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

**Установка gem:**
```ruby
# В Gemfile
gem 'cloudinary'
```

**Реализация:**
Файл `app/services/image_storage/cloudinary.rb` содержит заготовку. Необходимо реализовать методы аналогично S3.

## Telegram уведомления

### Настройка бота

1. Создайте бота через [@BotFather](https://t.me/BotFather)
2. Получите токен бота
3. Получите Chat ID канала или чата

**Получение Chat ID:**
- Для личного чата: напишите боту [@userinfobot](https://t.me/userinfobot)
- Для канала: добавьте бота в канал как администратора, затем отправьте сообщение в канал и перейдите по ссылке:
  `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`

### Настройка переменных окружения

```bash
# В .env файле
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
```

### Использование

Telegram уведомления автоматически отправляются при:
- Запуске задач парсинга
- Завершении задач парсинга
- Ошибках в задачах парсинга
- Получении курсов валют (успех или ошибка)

**Ручная отправка сообщения:**
```ruby
TelegramService.send_message("Текст сообщения", parse_mode: 'HTML')
```

## Проверка настроек

### Проверка облачного хранилища

```ruby
# В Rails console
ImageDownloader.storage
# Должно вернуть: ImageStorage::Local, ImageStorage::S3 или ImageStorage::Cloudinary

# Тест загрузки (для локального хранилища)
ImageDownloader.download_category_image(category, "https://example.com/image.jpg")
```

### Проверка Telegram

```ruby
# В Rails console
TelegramService.send_message("Тестовое сообщение")
# Проверьте, что сообщение пришло в указанный чат/канал
```

## Примеры .env файла

```bash
# Облачное хранилище
IMAGE_STORAGE_TYPE=local  # или s3, cloudinary

# AWS S3 (если используется)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_S3_BUCKET=my-bucket-name

# Cloudinary (если используется)
CLOUDINARY_CLOUD_NAME=my_cloud_name
CLOUDINARY_API_KEY=123456789012345
CLOUDINARY_API_SECRET=abcdefghijklmnopqrstuvwxyz123456

# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=-1001234567890

# Redis (для кеширования курсов валют)
REDIS_URL=redis://localhost:6379/0
```

