# Резюме: Категории без продуктов и варианты получения продуктов

## Что сделано

### 1. Создан rake task для проверки категорий без продуктов

**Файл:** `lib/tasks/categories.rake`

**Задачи:**
- `rake categories:check_empty` - проверяет все категории без продуктов и выводит статистику
- `rake categories:analyze_empty` - анализирует возможности получения продуктов для категорий без продуктов

### 2. Создан анализ вариантов получения продуктов

**Файл:** `docs/CATEGORY_PRODUCTS_ANALYSIS.md`

**Содержит:**
- Описание существующих методов получения продуктов
- 7 вариантов получения продуктов для категорий без продуктов
- Рекомендации по реализации
- План действий

## Как запустить проверку на проде

### Вариант 1: Через SSH и Docker

```bash
# 1. Подключиться к серверу
ssh deploy@45.135.234.22

# 2. Найти контейнер приложения
docker ps | grep ikea_api

# 3. Выполнить проверку (замените <container_id> на реальный ID)
docker exec -it <container_id> bundle exec rake categories:check_empty

# 4. Выполнить анализ (первые 50 категорий)
docker exec -it <container_id> bundle exec rake categories:analyze_empty
```

### Вариант 2: Через Rails console

```bash
# 1. Подключиться к серверу
ssh deploy@45.135.234.22

# 2. Найти контейнер
docker ps | grep ikea_api

# 3. Открыть Rails console
docker exec -it <container_id> bundle exec rails console

# 4. В консоли выполнить:
categories_without_products = Category.left_joins(:products)
                                     .where(products: { id: nil })
                                     .where(is_deleted: [false, nil])
                                     .select(:ikea_id, :name, :translated_name, :url, :is_popular, :is_important)
                                     .order(:name)

puts "Всего категорий без продуктов: #{categories_without_products.count}"

# Статистика по типам ID
numeric = categories_without_products.select { |c| c.ikea_id.to_s.match?(/^\d+$/) }
uuid = categories_without_products.select { |c| c.ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) }

puts "Числовые ID: #{numeric.count}"
puts "UUID: #{uuid.count}"

# Категории с URL
with_url = categories_without_products.where.not(url: [nil, '']).count
puts "С URL: #{with_url}"
puts "Без URL: #{categories_without_products.count - with_url}"
```

## Варианты получения продуктов для категорий без продуктов

### 1. ✅ API по ID категории (уже реализовано)
- **Работает для:** числовых ID
- **Не работает для:** UUID
- **Метод:** `IkeaApiService.search_products_by_category(category_id)`

### 2. ✅ API по названию категории (уже реализовано)
- **Работает для:** всех категорий с названием
- **Метод:** `CategoryProductsSearchService.search(category, strategies: [:api_by_category_name])`

### 3. ✅ HTML парсинг (уже реализовано)
- **Работает для:** категорий с URL
- **Метод:** `CategoryProductsFetcher.fetch(category.url)`

### 4. ⏳ Поиск через дочерние категории (не реализовано)
- **Идея:** Искать продукты в дочерних категориях
- **Применение:** Для категорий-контейнеров

### 5. ⏳ Поиск через родительские категории (не реализовано)
- **Идея:** Искать продукты в родительских категориях
- **Применение:** Для подкатегорий без продуктов

### 6. ⏳ Headless browser парсинг (не реализовано)
- **Идея:** Использовать Ferrum/Selenium для JS-рендеринг страниц
- **Применение:** Для категорий с динамически загружаемым контентом

### 7. ⏳ Альтернативные API endpoints (не реализовано)
- **Идея:** Исследовать другие endpoints IKEA API
- **Применение:** Для категорий, которые не работают через стандартный API

## Рекомендации

### Немедленные действия:
1. ✅ Запустить `rake categories:check_empty` на проде
2. ✅ Проанализировать результаты
3. ⏳ Для категорий с числовыми ID - попробовать `IkeaApiService.search_products_by_category`
4. ⏳ Для категорий с URL - попробовать `CategoryProductsFetcher.fetch`
5. ⏳ Для категорий с названием - попробовать поиск по названию

### Долгосрочные улучшения:
1. Реализовать поиск через дочерние категории
2. Улучшить HTML парсинг для более надежного извлечения продуктов
3. Исследовать альтернативные API endpoints
4. Добавить headless browser парсинг (опционально)

## Следующие шаги

1. **Запустить проверку на проде** - получить реальные данные о категориях без продуктов
2. **Проанализировать результаты** - понять, какие категории нуждаются в продуктах
3. **Применить существующие методы** - использовать `CategoryProductsSearchService` для поиска продуктов
4. **Реализовать новые методы** - добавить поиск через дочерние/родительские категории
5. **Мониторинг** - отслеживать категории без продуктов и автоматически пытаться найти продукты

