# Какие атрибуты сохраняются в БД

## Статус сохранения атрибутов

### ✅ Сохраняются в БД (21 из 22)

#### 1. Базовые атрибуты (8/8)
- ✅ `name` - Название продукта
- ✅ `sku` - Артикул
- ✅ `price` - Цена
- ✅ `weight` - Вес
- ✅ `dimensions` - Размеры
- ⚠️ `collection` - Коллекция (сохраняется, но не всегда заполнено)
- ✅ `images` - Изображения (JSON массив)
- ✅ `url` - URL продукта

#### 2. Описание продукта (3/3)
- ✅ `content` / `description` - Полное описание (сохраняется как `content`)
- ✅ `short_description` - Краткое описание
- ⚠️ `description_paragraphs` - **НЕ сохраняется отдельно** (только в `content`)

#### 3. Дополнительная информация (10/11)
- ✅ `designer` - Дизайнер
- ✅ `materials` - Материалы (текст)
- ⚠️ `materials_list` - **НЕ сохраняется отдельно** (только в `materials` как текст)
- ✅ `care_instructions` - Инструкции по уходу (текст)
- ⚠️ `care_instructions_list` - **НЕ сохраняется отдельно** (только в `care_instructions`)
- ✅ `safety_info` - Информация о безопасности (текст)
- ⚠️ `safety_info_list` - **НЕ сохраняется отдельно** (только в `safety_info`)
- ✅ `good_to_know` - Полезно знать (текст)
- ⚠️ `good_to_know_list` - **НЕ сохраняется отдельно** (только в `good_to_know`)
- ✅ `assembly_documents` - Документы (текст или JSON)
- ⚠️ `assembly_documents_list` - **НЕ сохраняется отдельно** (только в `assembly_documents`)

### ❌ НЕ сохраняются в БД (структурированные списки)

Следующие атрибуты извлекаются из scrape.do, но **не сохраняются отдельно** в БД, так как их данные уже включены в текстовые поля:

1. `description_paragraphs` - данные в `content`
2. `materials_list` - данные в `materials`
3. `care_instructions_list` - данные в `care_instructions`
4. `safety_info_list` - данные в `safety_info`
5. `good_to_know_list` - данные в `good_to_know`
6. `assembly_documents_list` - данные в `assembly_documents`

### Русские переводы

Все текстовые атрибуты имеют русские версии:
- ✅ `name_ru`
- ✅ `content_ru`
- ✅ `short_description_ru`
- ✅ `materials_ru`
- ✅ `care_instructions_ru`
- ✅ `safety_info_ru`
- ✅ `good_to_know_ru`
- ✅ `designer_ru`
- ✅ `features_ru`
- ✅ `environmental_info_ru`

## Рекомендации

Если нужны структурированные списки (JSON массивы), можно:
1. Добавить новые поля в БД (например, `materials_list`, `care_instructions_list`)
2. Или парсить текстовые поля при необходимости

Текущая реализация сохраняет данные в текстовом формате, что достаточно для большинства случаев использования.

