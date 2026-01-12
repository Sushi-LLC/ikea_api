# Настройка прокси для парсинга IKEA API

## Проблема

Cloudflare блокирует прямые запросы к IKEA API (HTTP 403). Для обхода блокировки необходимо использовать прокси-серверы.

## Настройка прокси на production

### 1. Формат прокси

Прокси указываются в переменной окружения `PROXY_LIST` в файле `/home/deploy/apps/ikea_back/shared/.env`:

```env
# Формат: http://username:password@proxy_host:port
# Можно указать несколько прокси через запятую (без пробелов):
PROXY_LIST="http://user1:pass1@proxy1.com:8080,http://user2:pass2@proxy2.com:8080"
```

### 2. Прокси без авторизации

Если прокси не требуют авторизации:

```env
PROXY_LIST="http://proxy1.com:8080,http://proxy2.com:8080"
```

### 3. Редактирование .env на проде

```bash
# Подключитесь к серверу
ssh deploy@45.135.234.22

# Отредактируйте .env
nano /home/deploy/apps/ikea_back/shared/.env

# Добавьте или обновите PROXY_LIST
PROXY_LIST="http://user:pass@proxy1.com:8080,http://user:pass@proxy2.com:8080"
```

### 4. Перезапуск приложения

После изменения `.env` необходимо перезапустить Sidekiq:

```bash
# Через Capistrano
bundle exec cap production sidekiq:restart

# Или напрямую на сервере
sudo systemctl restart ikea_back_sidekiq
```

## Как работает ProxyRotator

1. **Ротация прокси**: При каждом запросе используется следующий прокси из списка (round-robin)
2. **Автоматический ретрай**: Если прокси не работает (403, Cloudflare блокировка), автоматически пробуется следующий
3. **Fallback**: Если все прокси не работают, возвращается ошибка

## Где используется

- `IkeaApiService.fetch_categories` - получение категорий
- `IkeaApiService.search_products_by_category` - поиск продуктов по категории
- `IkeaApiService.fetch_product_details` - получение деталей продукта
- `CategoryProductsFetcher` - парсинг продуктов из HTML

## Рекомендации

1. **Резидентные прокси**: Используйте резидентные (статические) прокси для стабильной работы
2. **Несколько прокси**: Укажите несколько прокси для надежности
3. **Проверка прокси**: Убедитесь, что прокси работают и не заблокированы Cloudflare
4. **Ротация**: ProxyRotator автоматически ротирует прокси при ошибках

## Проверка работы

После настройки прокси проверьте логи:

```bash
ssh deploy@45.135.234.22 "journalctl -u ikea_back_sidekiq -n 50 --no-pager | grep ProxyRotator"
```

Должны увидеть:
```
ProxyRotator: Attempt 1/2 with proxy: proxy1.com:8080
```

Вместо:
```
ProxyRotator: PROXY_LIST is empty, trying without proxy
```

## Альтернативные решения

Если прокси недоступны, можно использовать:
- `scrape.do` API (уже настроен для главной страницы)
- Парсинг через HTML вместо API
- Использование других сервисов обхода блокировок
