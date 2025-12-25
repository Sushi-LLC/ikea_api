# Полный список атрибутов продукта IKEA

## Статистика
- **Всего атрибутов:** 22
- **Заполнено:** 21
- **Процент заполнения:** 95.5%

---

## 1. БАЗОВЫЕ АТРИБУТЫ (8)

| Атрибут | Ключ в БД | Тип | Описание | Статус |
|---------|-----------|-----|----------|--------|
| Название | `name` | string | Полное название продукта | ✓ |
| Артикул | `sku` | string | SKU/артикул продукта | ✓ |
| Цена | `price` | decimal | Цена продукта | ✓ |
| Вес | `weight` | decimal | Вес продукта в кг | ✓ |
| Размеры | `dimensions` | string | Размеры продукта (Ш×Г×В) | ✓ |
| Коллекция | `collection` | string | Название коллекции | ✗ |
| Изображения | `images` | json | Массив URL изображений | ✓ |
| URL продукта | `url` | string | URL страницы продукта | ✓ |

---

## 2. ОПИСАНИЕ ПРОДУКТА (3)

| Атрибут | Ключ в БД | Тип | Описание | Статус |
|---------|-----------|-----|----------|--------|
| Полное описание | `description` / `content` | text | Полное описание продукта (все параграфы) | ✓ |
| Параграфы описания | `description_paragraphs` | json | Массив параграфов описания | ✓ |
| Краткое описание | `short_description` | text | Первый параграф описания | ✓ |

---

## 3. ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ (11)

| Атрибут | Ключ в БД | Тип | Описание | Статус |
|---------|-----------|-----|----------|--------|
| Дизайнер | `designer` | string | Имя дизайнера продукта | ✓ |
| Материалы | `materials` | text | Полный текст материалов | ✓ |
| Список материалов | `materials_list` | json | Структурированный список материалов | ✓ |
| Инструкции по уходу | `care_instructions` | text | Полный текст инструкций по уходу | ✓ |
| Список инструкций по уходу | `care_instructions_list` | json | Структурированный список инструкций | ✓ |
| Информация о безопасности | `safety_info` | text | Полный текст информации о безопасности | ✓ |
| Список информации о безопасности | `safety_info_list` | json | Структурированный список информации | ✓ |
| Полезно знать | `good_to_know` | text | Полный текст "Полезно знать" | ✓ |
| Список "Полезно знать" | `good_to_know_list` | json | Структурированный список | ✓ |
| Документы по сборке | `assembly_documents` | text | URL документов (разделенные переносами) | ✓ |
| Список документов | `assembly_documents_list` | json | Массив объектов {title, url} | ✓ |

---

## Детальное описание атрибутов

### Материалы (materials_list)
Структурированный список материалов в формате:
```
[
  "Rama siedziska: Drewno w oklieinie laminowanej, lite drewno, sklejka, Płyta wiórowa, ...",
  "Sprężyny kieszeniowe: stal",
  "Rama dolna/ Noga: stal, Epoksydowa/poliestrowa powłoka proszkowa",
  ...
]
```

### Инструкции по уходу (care_instructions_list)
Список инструкций:
```
[
  "Rama, niezdejmowane pokrycie",
  "Odkurzać.",
  "Przecierać czystą, wilgotną szmatką."
]
```

### Информация о безопасности (safety_info_list)
Список информации:
```
[
  "Wytrzymałość tej tkaniny na ścieranie została przetestowana dla 30 000 cykli...",
  "Pokrycie ma poziom odporności wybarwień na światło 5...",
  "Ten mebel do siedzenia został przetestowany..."
]
```

### Документы (assembly_documents_list)
Массив объектов:
```json
[
  {
    "title": "ÄPPLARYD Sofa 2-osobowa",
    "url": "https://www.ikea.com/pl/pl/assembly_instructions/..."
  },
  {
    "title": "ÄPPLARYD Sofa 2-osobowa",
    "url": "https://www.ikea.com/pl/pl/manuals/..."
  }
]
```

---

## Источник данных

Все данные получены через **scrape.do API** с параметрами:
- `render=true` - рендеринг JavaScript
- `wait=5000` - ожидание 5 секунд для загрузки динамического контента
- `format=html` - формат ответа HTML

---

## Рекомендации по использованию

1. **Базовые атрибуты** - обязательны для всех продуктов
2. **Описание** - рекомендуется сохранять как `content` (полное) и `short_description` (краткое)
3. **Материалы** - сохранять в `materials` (текст) и `materials_list` (JSON для структурированного доступа)
4. **Инструкции по уходу** - сохранять в `care_instructions`
5. **Безопасность** - сохранять в `safety_info`
6. **Полезно знать** - сохранять в `good_to_know`
7. **Документы** - сохранять URL в `assembly_documents` (текст) и полную структуру в JSON

---

## Переводы

Все текстовые атрибуты должны иметь русские версии:
- `name_ru` - название на русском
- `content_ru` / `description_ru` - описание на русском
- `short_description_ru` - краткое описание на русском
- `materials_ru` - материалы на русском
- `care_instructions_ru` - инструкции по уходу на русском
- `safety_info_ru` - безопасность на русском
- `good_to_know_ru` - полезно знать на русском
- `designer_ru` - дизайнер на русском (если требуется)

