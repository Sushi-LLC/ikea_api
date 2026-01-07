# Улучшения парсинга продуктов с учетом нового подхода работы с категориями

## Обзор изменений

Доработан парсинг продуктов с учетом анализа категорий без продуктов на проде. Добавлена оптимизированная логика для категорий без продуктов, при этом сохранена полная обратная совместимость с существующим функционалом.

## Изменения

### 1. Модель Category (`app/models/category.rb`)

**Добавлены новые методы:**

- `has_products?` - проверка наличия продуктов в категории
- `numeric_id?` - проверка, является ли ID категории числовым
- `uuid_id?` - проверка, является ли ID категории UUID

**Использование:**
```ruby
category = Category.find_by(ikea_id: '700403')
category.has_products?  # => false
category.numeric_id?    # => true
category.uuid_id?       # => false
```

### 2. Сервис CategoryProductsSearchService (`app/services/category_products_search_service.rb`)

**Добавлен новый метод:**

- `optimal_strategies_for_category(category)` - определяет оптимальный порядок стратегий на основе анализа

**Логика определения стратегий:**

Для категорий с числовыми ID:
1. HTML парсинг (приоритет 1) - все категории без продуктов имеют URL
2. API по ID (приоритет 2)
3. Альтернативный endpoint (приоритет 3)
4. API по названию (приоритет 4, fallback)

Для категорий с UUID или другими форматами:
1. HTML парсинг (приоритет 1)
2. API по названию (приоритет 2, fallback)

**Улучшено логирование:**
- Добавлены метрики успешных стратегий
- Логирование деталей категории (has_url, numeric_id, etc.)

**Использование:**
```ruby
category = Category.find_by(ikea_id: '700403')
strategies = CategoryProductsSearchService.optimal_strategies_for_category(category)
# => [:html_parsing, :api_by_category_id, :api_alternative_endpoint, :api_by_category_name]

products = CategoryProductsSearchService.search(
  category,
  offset: 0,
  limit: 50,
  strategies: strategies
)
```

### 3. Job ParseProductsJob (`app/jobs/parse_products_job.rb`)

**Улучшена логика обработки категорий:**

1. **Проверка наличия продуктов:**
   - Используется `category.has_products?` для определения, есть ли уже продукты в категории

2. **Оптимизированный порядок стратегий для категорий без продуктов:**
   - Для категорий БЕЗ продуктов используется `optimal_strategies_for_category`
   - Приоритет HTML парсинга (все категории без продуктов имеют URL)
   - Для категорий С продуктами сохраняется стандартный порядок (обратная совместимость)

3. **Улучшено логирование:**
   - Логирование успешного поиска продуктов для ранее пустых категорий
   - Детальная информация о категории при неудаче

**Пример работы:**

```ruby
# Категория без продуктов (ID: 700403)
# Используется оптимизированный порядок:
# 1. HTML парсинг (приоритет 1)
# 2. API по ID (приоритет 2)
# 3. Альтернативный endpoint (приоритет 3)
# 4. API по названию (приоритет 4)

# Категория с продуктами (ID: 12345)
# Используется стандартный порядок (обратная совместимость):
# 1. API по ID
# 2. Альтернативный endpoint
# 3. API по названию
# 4. HTML парсинг
```

## Обратная совместимость

✅ **Все изменения полностью обратно совместимы:**

1. Категории с существующими продуктами обрабатываются как раньше
2. Существующие вызовы `CategoryProductsSearchService.search` работают без изменений
3. Стандартный порядок стратегий сохранен для категорий с продуктами
4. Новые методы в Category не влияют на существующий код

## Преимущества

1. **Оптимизированный поиск для категорий без продуктов:**
   - HTML парсинг имеет приоритет (все категории имеют URL)
   - Более высокая вероятность найти продукты

2. **Улучшенное логирование:**
   - Метрики успешных стратегий
   - Детальная информация для отладки

3. **Гибкость:**
   - Автоматическое определение оптимальных стратегий
   - Возможность ручной настройки при необходимости

## Тестирование

### Проверка обратной совместимости:

```ruby
# Существующий код должен работать без изменений
category = Category.find_by(ikea_id: '12345')
products = CategoryProductsSearchService.search(category)
# => Работает как раньше
```

### Проверка нового функционала:

```ruby
# Категория без продуктов
category = Category.left_joins(:products)
                   .where(products: { id: nil })
                   .first

# Автоматически используется оптимизированный порядок стратегий
ParseProductsJob.new.perform(category_id: category.ikea_id)
```

## Метрики и мониторинг

Логи содержат следующую информацию:

1. **Успешные стратегии:**
   ```
   CategoryProductsSearchService: Strategy html_parsing found 25 products for category 700403
   CategoryProductsSearchService: Success metrics - category_id: 700403, strategy: html_parsing, products_count: 25, has_url: true, numeric_id: true
   ```

2. **Успешный поиск для пустых категорий:**
   ```
   ParseProductsJob: SUCCESS - Found 25 products for previously empty category 700403 (AGD do kuchni ÄSPINGE)
   ```

3. **Неудачные попытки:**
   ```
   ParseProductsJob: No products found for category ... after all attempts
   ParseProductsJob: Category details - has_url: true, numeric_id: true, uuid_id: false
   ```

## Следующие шаги

1. ✅ Доработка парсинга завершена
2. ⏳ Мониторинг эффективности на проде
3. ⏳ Сбор статистики по успешным стратегиям
4. ⏳ Оптимизация на основе реальных данных

