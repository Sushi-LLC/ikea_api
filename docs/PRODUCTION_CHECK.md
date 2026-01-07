# Инструкция по проверке категорий без продуктов на проде

## Способ 1: Через Kamal (рекомендуется)

```bash
# Проверка категорий без продуктов
bundle exec kamal app exec "bundle exec rake categories:check_empty"

# Анализ возможностей получения продуктов (первые 50 категорий)
bundle exec kamal app exec "bundle exec rake categories:analyze_empty"
```

## Способ 2: Через SSH и Docker напрямую

```bash
# Подключение к серверу
ssh deploy@45.135.234.22

# Найти контейнер приложения
docker ps | grep ikea_api

# Выполнить rake task
docker exec -it <container_id> bundle exec rake categories:check_empty
```

## Способ 3: Через Rails console

```bash
# Открыть Rails console на проде
bundle exec kamal app exec "bundle exec rails console"

# В консоли выполнить:
categories_without_products = Category.left_joins(:products)
                                     .where(products: { id: nil })
                                     .where(is_deleted: [false, nil])
                                     .count

puts "Категорий без продуктов: #{categories_without_products}"
```

## Результаты

После выполнения задач результаты будут выведены в консоль:
- Общее количество категорий без продуктов
- Статистика по типам ID (числовые, UUID, другие)
- Список категорий с деталями
- Статистика по наличию URL
- Важные категории без продуктов

