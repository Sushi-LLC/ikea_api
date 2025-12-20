# 🚀 Руководство по переписыванию IKEA Parser на Ruby/Rails

Полная инструкция для миграции Node.js парсера IKEA на Ruby on Rails приложение.

---

## 📋 Содержание

1. [Обзор архитектуры](#обзор-архитектуры)
2. [API Endpoints IKEA](#api-endpoints-ikea)
3. [Прокси-серверы](#прокси-серверы)
4. [База данных](#база-данных)
5. [Модели данных](#модели-данных)
6. [Сервисы и бизнес-логика](#сервисы-и-бизнес-логика)
7. [Парсинг HTML](#парсинг-html)
8. [Сервисы перевода](#сервисы-перевода)
9. [Расчет доставки](#расчет-доставки)
10. [Планировщик задач](#планировщик-задач)
11. [API Endpoints приложения](#api-endpoints-приложения)
12. [Переменные окружения](#переменные-окружения)
13. [Зависимости и гемы](#зависимости-и-гемы)
14. [Миграция данных](#миграция-данных)

---

## 🏗️ Обзор архитектуры

### Текущая структура (Node.js)
```
src/
├── config/          # Конфигурация БД
├── models/          # Mongoose модели
├── services/        # Бизнес-логика
├── utils/           # Утилиты (парсинг, переводы, прокси)
├── routes/           # Express маршруты
├── scripts/         # Скрипты для выполнения задач
└── scheduler.js     # Планировщик задач (cron)
```

### Целевая структура (Rails)
```
app/
├── models/          # ActiveRecord модели
├── services/        # Сервисные классы
├── jobs/            # Background jobs (Sidekiq/ActiveJob)
├── controllers/     # API контроллеры
├── lib/             # Утилиты и парсеры
└── config/          # Конфигурация
```

---

## 🌐 API Endpoints IKEA

### 1. Поиск товаров по категории

**Endpoint:**
```
POST https://sik.search.blue.cdtapps.com/pl/pl/search?c=listaf&v=20241114
```

**Headers:**
```ruby
{
  'Content-Type' => 'application/json',
  'User-Agent' => 'Mozilla/5.0...',
  'Accept' => 'application/json'
}
```

**Request Body:**
```ruby
{
  searchParameters: {
    input: category_id,  # ID категории (например, "10412")
    type: 'CATEGORY'
  },
  zip: '01-106',        # Почтовый индекс
  store: '307',          # ID магазина
  isUserLoggedIn: false,
  components: [{
    component: 'PRIMARY_AREA',
    columns: 4,
    types: {
      main: 'PRODUCT',
      breakouts: ['PLANNER', 'LOGIN_REMINDER', 'MATTRESS_WARRANTY']
    },
    filterConfig: { 'max-num-filters': 6 },
    sort: 'RELEVANCE',
    window: {
      offset: 0,         # Пагинация
      size: 50           # Размер страницы
    }
  }]
}
```

**Response Structure:**
```ruby
{
  results: [{
    items: [{
      type: 'PRODUCT',
      product: {
        id: '403.411.01',           # SKU
        typeName: 'IKEA 365+...',    # Название
        itemNo: '40341101',         # Артикул
        itemNoGlobal: '40341101',   # Глобальный артикул
        pipUrl: '/pl/pl/p/...',     # URL товара
        salesPrice: {
          numeral: 99.99            # Цена
        },
        homeDelivery: 'available',  # Доступность доставки
        gprDescription: {
          variants: [...]           # Варианты товара
        }
      }
    }]
  }]
}
```

**Ruby реализация:**
```ruby
# app/services/ikea_api_service.rb
class IkeaApiService
  SEARCH_URL = 'https://sik.search.blue.cdtapps.com/pl/pl/search?c=listaf&v=20241114'
  PAGE_SIZE = 50

  def self.search_products_by_category(category_id, offset: 0, limit: PAGE_SIZE)
    response = HTTParty.post(
      SEARCH_URL,
      body: {
        searchParameters: {
          input: category_id,
          type: 'CATEGORY'
        },
        zip: '01-106',
        store: '307',
        isUserLoggedIn: false,
        components: [{
          component: 'PRIMARY_AREA',
          columns: 4,
          types: {
            main: 'PRODUCT',
            breakouts: ['PLANNER', 'LOGIN_REMINDER', 'MATTRESS_WARRANTY']
          },
          filterConfig: { 'max-num-filters': 6 },
          sort: 'RELEVANCE',
          window: { offset: offset, size: limit }
        }]
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'User-Agent' => 'Mozilla/5.0...'
      },
      proxy: get_proxy  # См. раздел Прокси
    )

    parse_search_response(response)
  end

  private

  def self.parse_search_response(response)
    return [] unless response.success?

    items = response.dig('results', 0, 'items') || []
    items.select { |item| item['type'] == 'PRODUCT' }
        .map { |item| item['product'] }
  end
end
```

### 2. Получение категорий

**Endpoint:**
```
GET https://www.ikea.com/pl/pl/meta-data/navigation/catalog-products-slim.json
```

**Headers:**
```ruby
{
  'User-Agent' => 'Wget/1.21.4',
  'Accept' => '*/*',
  'Accept-Encoding' => 'identity',
  'Connection' => 'Keep-Alive',
  'Referer' => 'https://www.ikea.com/pl/pl/'
}
```

**Response:** JSON массив с древовидной структурой категорий

**Ruby реализация:**
```ruby
class IkeaApiService
  CATEGORIES_URL = 'https://www.ikea.com/pl/pl/meta-data/navigation/catalog-products-slim.json'

  def self.fetch_categories
    response = HTTParty.get(
      CATEGORIES_URL,
      headers: {
        'User-Agent' => 'Wget/1.21.4',
        'Accept' => '*/*',
        'Accept-Encoding' => 'identity',
        'Connection' => 'Keep-Alive',
        'Referer' => 'https://www.ikea.com/pl/pl/'
      },
      proxy: get_proxy
    )

    JSON.parse(response.body) if response.success?
  end
end
```

### 3. Проверка наличия товара

**Endpoint:**
```
GET https://api.salesitem.ingka.com/availabilities/ru/pl?itemNos={itemNo1},{itemNo2},...
```

**Headers:**
```ruby
{
  'x-client-id' => client_id,  # Получается через Puppeteer (см. getClientId.js)
  'Accept' => 'application/json'
}
```

**Response:**
```ruby
{
  availabilities: [{
    itemNo: '40341101',
    buyingOption: {
      homeDelivery: {
        availability: {
          quantity: 10,
          parcel: true  # Является ли посылкой
        }
      }
    }
  }]
}
```

**Ruby реализация:**
```ruby
class IkeaApiService
  AVAILABILITY_URL = 'https://api.salesitem.ingka.com/availabilities/ru/pl'

  def self.check_availability(item_nos, client_id)
    item_nos_str = Array(item_nos).join(',')
    
    response = HTTParty.get(
      "#{AVAILABILITY_URL}?itemNos=#{item_nos_str}",
      headers: {
        'x-client-id' => client_id,
        'Accept' => 'application/json'
      },
      proxy: get_proxy
    )

    parse_availability_response(response)
  end

  private

  def self.parse_availability_response(response)
    return {} unless response.success?

    availabilities = response.dig('availabilities') || []
    result = {}
    
    availabilities.each do |avail|
      item_no = avail['itemNo']
      buying_option = avail.dig('buyingOption', 'homeDelivery', 'availability')
      
      result[item_no] = {
        quantity: buying_option&.dig('quantity') || 0,
        is_parcel: buying_option&.dig('parcel') || false
      }
    end
    
    result
  end
end
```

### 4. Получение x-client-id

**Важно:** `x-client-id` требуется для API наличия. Получается через браузерную автоматизацию.

**Node.js реализация:** Использует Puppeteer для перехвата заголовков.

**Ruby реализация:**
```ruby
# app/lib/ikea_client_id_fetcher.rb
require 'selenium-webdriver'

class IkeaClientIdFetcher
  def self.fetch_client_id(product_url)
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-setuid-sandbox')
    
    driver = Selenium::WebDriver.for :chrome, options: options
    
    client_id = nil
    
    driver.execute_cdp('Network.enable')
    driver.execute_cdp('Network.setRequestInterception', patterns: ['*'])
    
    driver.execute_cdp('Network.requestIntercepted') do |params|
      if params['request']['url'].include?('api.salesitem.ingka.com/availabilities')
        headers = params['request']['headers']
        client_id = headers['x-client-id']
      end
    end
    
    driver.navigate.to(product_url)
    sleep(5)  # Ждем загрузки
    
    driver.quit
    
    client_id
  end
end
```

**Альтернатива (более легковесная):**
```ruby
# Использовать механический браузер (Mechanize) или сохранять client_id в кэше
# и обновлять периодически
```

---

## 🔄 Прокси-серверы

### Список прокси

**Текущие прокси (из proxyAxios.js):**
```ruby
PROXY_LIST = [
  'http://UaAMsJ7P:kqKvmSxX@146.19.126.214:63556',
  'http://UaAMsJ7P:kqKvmSxX@88.204.45.198:64520',
  'http://UaAMsJ7P:kqKvmSxX@156.243.158.105:63578'
]
```

### Реализация ротации прокси

**Ruby реализация:**
```ruby
# app/lib/proxy_rotator.rb
class ProxyRotator
  PROXY_LIST = [
    'http://UaAMsJ7P:kqKvmSxX@146.19.126.214:63556',
    'http://UaAMsJ7P:kqKvmSxX@88.204.45.198:64520',
    'http://UaAMsJ7P:kqKvmSxX@156.243.158.105:63578'
  ].freeze

  MAX_RETRIES = 5
  
  @current_index = 0
  @mutex = Mutex.new

  def self.get_proxy
    # Round-robin для новых запросов
    @mutex.synchronize do
      proxy = PROXY_LIST[@current_index]
      @current_index = (@current_index + 1) % PROXY_LIST.length
      proxy
    end
  end

  def self.with_proxy_retry(&block)
    # Более сложная логика с сохранением индекса для ретраев
    last_error = nil
    proxy_index = 0
    
    PROXY_LIST.length.times do |attempt|
      proxy = PROXY_LIST[proxy_index]
      
      begin
        return yield(proxy)
      rescue => e
        last_error = e
        
        # Если 403 ошибка и есть еще прокси - пробуем следующий
        if (e.message.include?('403') || (e.respond_to?(:response) && e.response&.status == 403)) && 
           attempt < PROXY_LIST.length - 1
          proxy_index = (proxy_index + 1) % PROXY_LIST.length
          next
        end
        
        raise e if attempt == PROXY_LIST.length - 1
      end
    end
    
    raise last_error || StandardError.new('All proxies failed')
  end
end

# Использование в HTTParty
class IkeaApiService
  def self.get_proxy
    proxy_url = ProxyRotator.get_proxy
    uri = URI.parse(proxy_url)
    
    {
      http_proxyaddr: uri.host,
      http_proxyport: uri.port,
      http_proxyuser: uri.user,
      http_proxypass: uri.password
    }
  end
end
```

**Или с использованием гема `httparty` и `proxy` опции:**
```ruby
HTTParty.get(url, http_proxyaddr: proxy_host, http_proxyport: proxy_port, ...)
```

---

## 🗄️ База данных

### Текущая БД: MongoDB

**Connection String:**
```
mongodb://localhost:27017/ikea
```

**Настройки подключения:**
```ruby
# config/mongoid.yml (если используете Mongoid)
development:
  clients:
    default:
      database: ikea
      hosts:
        - localhost:27017
      options:
        server_selection_timeout_ms: 30000
        socket_timeout_ms: 0
        connect_timeout_ms: 30000
        max_pool_size: 10
        min_pool_size: 2
        max_idle_time_ms: 30000
```

### Альтернатива: PostgreSQL

**Миграция на PostgreSQL рекомендуется для Rails приложения.**

**Настройки:**
```ruby
# config/database.yml
development:
  adapter: postgresql
  encoding: unicode
  database: ikea_development
  pool: 10
  timeout: 5000
  host: localhost
  port: 5432
```

**См. раздел [Миграция данных](#миграция-данных) для деталей.**

---

## 📦 Модели данных

### 1. Product (Товар)

**MongoDB Schema → ActiveRecord Model:**

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  # Индексы
  validates :sku, presence: true, uniqueness: true
  validates :item_no, presence: true
  
  # Связи
  belongs_to :category, foreign_key: :category_id, primary_key: :ikea_id, optional: true
  has_many :product_filter_values
  has_many :filter_values, through: :product_filter_values
  
  # Callbacks
  before_create :generate_unique_id
  after_save :calculate_delivery
  
  # Scopes
  scope :bestsellers, -> { where(is_bestseller: true) }
  scope :popular, -> { where(is_popular: true) }
  scope :translated, -> { where(translated: true) }
  
  # Методы
  def self.find_by_sku(sku)
    find_by(sku: sku)
  end
  
  def translated_name
    name_ru.presence || name
  end
  
  private
  
  def generate_unique_id
    return if unique_id.present?
    
    max_id = Product.maximum(:unique_id) || 0
    self.unique_id = max_id + 1 + rand(100)  # Случайное смещение для параллельной обработки
  end
  
  def calculate_delivery
    return unless weight.present? && weight > 0
    
    delivery_result = DeliveryService.calculate_product_delivery(
      weight: weight,
      is_parcel: is_parcel,
      order_value: price || 0
    )
    
    if delivery_result[:success]
      update_columns(
        delivery_type: delivery_result[:data][:selected_type][:id],
        delivery_name: delivery_result[:data][:selected_type][:name],
        delivery_cost: delivery_result[:data][:cost],
        delivery_reason: delivery_result[:data][:selected_type][:reason]
      )
    end
  end
end
```

**Миграция:**
```ruby
# db/migrate/xxx_create_products.rb
class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products do |t|
      t.string :sku, null: false, index: { unique: true }
      t.integer :unique_id, index: { unique: true }
      t.string :name
      t.string :name_ru
      t.string :collection
      t.string :item_no
      t.string :url
      t.text :variants, array: true, default: []
      t.text :related_products, array: true, default: []
      t.text :set_items, array: true, default: []
      t.text :bundle_items, array: true, default: []
      t.text :images, array: true, default: []
      t.text :local_images, array: true, default: []
      t.integer :images_total, default: 0
      t.integer :images_stored, default: 0
      t.boolean :images_incomplete, default: false
      t.text :manuals, array: true, default: []
      t.text :videos, array: true, default: []
      t.decimal :price, precision: 10, scale: 2
      t.string :home_delivery
      t.text :content
      t.text :content_ru
      t.text :good_info
      t.text :good_info_ru
      t.text :material_info
      t.text :material_info_ru
      t.decimal :weight, precision: 10, scale: 2, default: 0
      t.decimal :net_weight, precision: 10, scale: 2, default: 0
      t.decimal :package_volume, precision: 10, scale: 2, default: 0
      t.string :package_dimensions
      t.string :dimensions
      t.integer :quantity, default: 0
      t.boolean :is_parcel, default: false
      t.boolean :translated, default: false
      t.boolean :is_bestseller, default: false
      t.boolean :is_popular, default: false
      t.string :category_id
      t.string :delivery_type
      t.string :delivery_name
      t.decimal :delivery_cost, precision: 10, scale: 2
      t.string :delivery_reason
      
      t.timestamps
    end
    
    add_index :products, :updated_at
    add_index :products, :category_id
    add_index :products, :is_bestseller
    add_index :products, :is_popular
  end
end
```

### 2. Category (Категория)

```ruby
# app/models/category.rb
class Category < ApplicationRecord
  validates :ikea_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :url, presence: true
  
  # Связи
  has_many :products, foreign_key: :category_id, primary_key: :ikea_id
  
  # Callbacks
  before_create :generate_unique_id
  
  # Scopes
  scope :popular, -> { where(is_popular: true) }
  scope :not_deleted, -> { where(is_deleted: false) }
  
  def translated_name
    translated_name.presence || name
  end
  
  private
  
  def generate_unique_id
    return if unique_id.present?
    
    max_id = Category.maximum(:unique_id) || 0
    self.unique_id = max_id + 1
  end
end
```

**Миграция:**
```ruby
# db/migrate/xxx_create_categories.rb
class CreateCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :categories do |t|
      t.string :ikea_id, null: false, index: { unique: true }
      t.integer :unique_id, index: { unique: true }
      t.string :name, null: false
      t.string :translated_name
      t.string :url, null: false
      t.string :remote_image_url
      t.string :local_image_path
      t.text :parent_ids, array: true, default: []
      t.boolean :is_deleted, default: false
      t.boolean :is_important, default: false
      t.boolean :is_popular, default: false
      t.boolean :translated, default: false
      
      t.timestamps
    end
  end
end
```

### 3. Filter и FilterValue

```ruby
# app/models/filter.rb
class Filter < ApplicationRecord
  validates :parameter, presence: true, uniqueness: true
  
  has_many :filter_values, dependent: :destroy
end

# app/models/filter_value.rb
class FilterValue < ApplicationRecord
  belongs_to :filter
  has_many :product_filter_values
  has_many :products, through: :product_filter_values
  
  validates :value_id, presence: true, uniqueness: true
end

# app/models/product_filter_value.rb (join table)
class ProductFilterValue < ApplicationRecord
  belongs_to :product
  belongs_to :filter_value
end
```

### 4. User (Пользователь)

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  
  validates :username, presence: true, uniqueness: true
  validates :email, uniqueness: true, allow_nil: true
  validates :role, inclusion: { in: %w[user admin] }
  
  enum role: { user: 0, admin: 1 }
  
  scope :active, -> { where(is_active: true) }
end
```

---

## 🔧 Сервисы и бизнес-логика

### 1. ProductService (Синхронизация товаров)

```ruby
# app/services/product_service.rb
class ProductService
  CONCURRENCY = 5
  PAGE_SIZE = 50
  
  def self.sync_products(limit: nil, products_per_category: nil)
    new.sync_products(limit: limit, products_per_category: products_per_category)
  end
  
  def sync_products(limit: nil, products_per_category: nil)
    categories = Category.not_deleted
    
    created_count = 0
    updated_count = 0
    processed_count = 0
    
    # Мониторинг памяти
    @last_memory_check = 0
    MEMORY_CHECK_INTERVAL = 1000
    
    categories.find_each do |category|
      break if limit && processed_count >= limit
      
      # Проверка памяти
      check_memory(processed_count)
      
      sync_category_products(
        category,
        limit: products_per_category,
        total_limit: limit,
        processed_count: processed_count
      ) do |created, updated, processed|
        created_count += created
        updated_count += updated
        processed_count = processed
      end
    end
    
    {
      created: created_count,
      updated: updated_count,
      processed: processed_count
    }
  end
  
  def check_memory(processed_count)
    return unless processed_count - @last_memory_check >= MEMORY_CHECK_INTERVAL
    
    @last_memory_check = processed_count
    mem_usage = `ps -o rss= -p #{Process.pid}`.to_i / 1024 # MB
    
    Rails.logger.info("📊 Memory: #{mem_usage}MB (processed: #{processed_count})")
    
    if mem_usage > 200
      Rails.logger.warn("⚠️ High memory usage: #{mem_usage}MB")
    end
    
    if mem_usage > 300
      GC.start
      Rails.logger.info("🧹 Garbage collection triggered")
    end
  end
  
  private
  
  def sync_category_products(category, limit:, total_limit:, processed_count:)
    offset = 0
    created = 0
    updated = 0
    processed = processed_count
    
    loop do
      break if limit && processed >= processed_count + limit
      break if total_limit && processed >= total_limit
      
      products_data = IkeaApiService.search_products_by_category(
        category.ikea_id,
        offset: offset,
        limit: PAGE_SIZE
      )
      
      break if products_data.empty?
      
      products_data.each do |product_data|
        break if limit && processed >= processed_count + limit
        break if total_limit && processed >= total_limit
        
        result = process_product(product_data, category)
        created += 1 if result[:created]
        updated += 1 if result[:updated]
        processed += 1
      end
      
      offset += PAGE_SIZE
      break if products_data.length < PAGE_SIZE
    end
    
    yield(created, updated, processed)
  end
  
  def process_product(product_data, category)
    sku = product_data['id']
    product = Product.find_by(sku: sku)
    
    # Получаем детальную информацию
    pl_details = fetch_pl_details(product_data['pipUrl'])
    lt_details = fetch_lt_details(product_data['itemNoGlobal'] || product_data['itemNo'])
    
    # Формируем атрибуты
    attributes = build_product_attributes(product_data, pl_details, lt_details, category)
    
    # Сохранение с обработкой ошибок и ретраями
    save_product_with_retry(product, attributes)
  end
  
  def save_product_with_retry(product, attributes, max_retries: 3)
    retry_count = 0
    
    while retry_count < max_retries
      begin
        # Проверка соединения с БД
        unless ActiveRecord::Base.connection.active?
          Rails.logger.warn('⚠️ Database connection lost. Reconnecting...')
          ActiveRecord::Base.establish_connection
        end
        
        if product
          product.update!(attributes)
          return { created: false, updated: true }
        else
          # Создание с обработкой дубликатов uniqueId
          begin
            Product.create!(attributes)
            return { created: true, updated: false }
          rescue ActiveRecord::RecordNotUnique => e
            if e.message.include?('unique_id')
              # Генерируем новый unique_id и пробуем снова
              attributes[:unique_id] = generate_unique_id
              retry
            else
              raise
            end
          end
        end
      rescue ActiveRecord::StatementInvalid => e
        # Обработка ошибок соединения
        if e.message.include?('connection') || e.message.include?('not connected') || 
           e.message.include?('buffering timed out')
          retry_count += 1
          if retry_count >= max_retries
            Rails.logger.error("❌ Failed to save product #{attributes[:sku]} after #{max_retries} retries (connection issue)")
            return { created: false, updated: false, error: 'Connection failed' }
          end
          Rails.logger.warn("⚠️ Connection issue. Retry #{retry_count}/#{max_retries}...")
          sleep(1 * retry_count)
          ActiveRecord::Base.establish_connection
          retry
        else
          raise
        end
      end
    end
    
    { created: false, updated: false, error: 'Max retries exceeded' }
  end
  
  def generate_unique_id
    max_id = Product.maximum(:unique_id) || 0
    max_id + 1 + rand(100)  # Случайное смещение для параллельной обработки
  end
  
  def build_product_attributes(api_data, pl_details, lt_details, category)
    weight = pl_details[:weight] || 0
    
    # Определяем, является ли товар посылкой (parcel) на основе веса
    # Товары до 30 кг считаются посылками
    is_parcel = weight > 0 && weight <= 30
    
    {
      sku: api_data['id'],
      name: api_data['typeName'],
      name_ru: lt_details[:name] || pl_details[:name],
      item_no: api_data['itemNoGlobal'] || api_data['itemNo'],
      url: "https://www.ikea.com#{api_data['pipUrl']}",
      price: api_data.dig('salesPrice', 'numeral'),
      home_delivery: api_data['homeDelivery'],
      variants: api_data.dig('gprDescription', 'variants') || [],
      collection: pl_details[:collection],
      images: pl_details[:images] || [],
      videos: pl_details[:videos] || [],
      manuals: pl_details[:manuals] || [],
      set_items: pl_details[:set_items] || [],
      bundle_items: pl_details[:bundle_items] || [],
      related_products: pl_details[:related_products] || [],
      weight: weight,
      net_weight: pl_details[:net_weight] || 0,
      package_volume: pl_details[:package_volume] || 0,
      package_dimensions: pl_details[:package_dimensions] || '',
      dimensions: pl_details[:dimensions] || '',
      is_parcel: is_parcel,
      content: lt_details[:details_text],
      content_ru: lt_details[:details_text],
      material_info: lt_details[:material_text],
      material_info_ru: lt_details[:material_text],
      good_info: lt_details[:good_text],
      good_info_ru: lt_details[:good_text],
      translated: lt_details[:translated] || false,
      category_id: category.ikea_id
    }
  end
  
  def fetch_pl_details(url)
    PlDetailsFetcher.fetch(url)
  end
  
  def fetch_lt_details(item_no)
    LtDetailsFetcher.fetch(item_no)
  end
end
```

### 2. CategoryService (Синхронизация категорий)

```ruby
# app/services/category_service.rb
class CategoryService
  def self.sync_categories(limit: nil)
    new.sync_categories(limit: limit)
  end
  
  def sync_categories(limit: nil)
    categories_data = IkeaApiService.fetch_categories
    return { created: 0, updated: 0 } unless categories_data
    
    # Построение parentMap и nodeMap
    parent_map = {}
    node_map = {}
    
    build_category_maps(categories_data, parent_map, node_map)
    
    # Обработка категорий
    categories_to_process = limit ? 
      select_leaf_categories(parent_map, limit) : 
      parent_map.keys
    
    created = 0
    updated = 0
    
    categories_to_process.each do |cat_id|
      node = node_map[cat_id]
      next unless node
      
      parents = Array(parent_map[cat_id])
      
      category = Category.find_or_initialize_by(ikea_id: cat_id)
      
      # Перевод названия (используем существующий перевод, если новый не получен)
      translated_name = translate_category_name(node['name'], category)
      
      category.assign_attributes(
        name: node['name'],
        translated_name: translated_name,
        url: node['url'] || '',
        remote_image_url: node['im'],
        parent_ids: parents,
        translated: false  # MyMemory не является переводом с IKEA Lithuania
      )
      
      if category.new_record?
        category.save!
        created += 1
      elsif category.changed?
        category.save!
        updated += 1
      end
    end
    
    { created: created, updated: updated }
  end
  
  private
  
  def build_category_maps(nodes, parent_map, node_map, parent_id: nil)
    Array(nodes).each do |node|
      id = node['id']&.to_s
      next unless id
      
      node_map[id] = node
      parent_map[id] ||= Set.new
      parent_map[id].add(parent_id) if parent_id
      
      children = node['subs'] || node['children'] || []
      build_category_maps(children, parent_map, node_map, parent_id: id)
    end
  end
  
  def select_leaf_categories(parent_map, limit)
    parent_ids = Set.new
    parent_map.each_value { |parents| parents.each { |p| parent_ids.add(p) } }
    
    leaf_categories = parent_map.keys.reject { |id| parent_ids.include?(id) }
    leaf_categories.first(limit)
  end
  
  def translate_category_name(name, existing_category = nil)
    # Используем только MyMemory (бесплатный, не требует ключа)
    # Если MyMemory не сработал, но есть старый перевод - используем его
    begin
      TranslationService.translate_with_my_memory(name, 'ru', 'pl')
    rescue => e
      Rails.logger.warn("⚠️ MyMemory translation failed for #{name}: #{e.message}")
      # Если есть существующий перевод - сохраняем его
      existing_category&.translated_name
    end
  end
end
```

### 3. OffersService (Обновление офферов)

```ruby
# app/services/offers_service.rb
class OffersService
  def self.update_offers
    new.update_offers
  end
  
  def update_offers
    updated_count = 0
    
    Category.not_deleted.find_each do |category|
      update_category_offers(category) do |updated|
        updated_count += updated
      end
    end
    
    { updated: updated_count }
  end
  
  private
  
  def update_category_offers(category)
    offset = 0
    updated = 0
    
    loop do
      products_data = IkeaApiService.search_products_by_category(
        category.ikea_id,
        offset: offset,
        limit: 50
      )
      
      break if products_data.empty?
      
      products_data.each do |product_data|
        sku = product_data['id']
        product = Product.find_by(sku: sku)
        next unless product
        
        product.update!(
          price: product_data.dig('salesPrice', 'numeral'),
          home_delivery: product_data['homeDelivery']
        )
        
        updated += 1
      end
      
      offset += 50
      break if products_data.length < 50
    end
    
    yield(updated)
  end
end
```

---

## 🕷️ Парсинг HTML

### 1. Парсинг страницы товара IKEA Poland

```ruby
# app/lib/pl_details_fetcher.rb
require 'nokogiri'
require 'open-uri'

class PlDetailsFetcher
  def self.fetch(url)
    new.fetch(url)
  end
  
  def fetch(url)
    full_url = url.start_with?('http') ? url : "https://www.ikea.com#{url}"
    
    html = fetch_with_proxy(full_url)
    doc = Nokogiri::HTML(html)
    
    result = {}
    
    # JSON-LD Product schema
    product_schema = extract_json_ld(doc)
    if product_schema
      result[:name] = product_schema['name']
      result[:sku] = product_schema['mpn']
      result[:images] = Array(product_schema['image'])
      if product_schema['offers']
        result[:price] = product_schema['offers']['price']
      end
    end
    
    # Collection
    collection = doc.css('.pip-header-section__title--big').text.strip
    result[:collection] = collection if collection.present?
    
    # Product data (hydration props)
    product_data_attr = doc.css('.js-product-pip').first&.attribute('data-hydration-props')&.value
    if product_data_attr
      product_data = JSON.parse(product_data_attr)
      result[:product_data] = product_data
      
      # Set items
      result[:set_items] = extract_set_items(product_data, doc)
      
      # Bundle items
      result[:bundle_items] = extract_bundle_items(product_data, doc)
      
      # Related products
      result[:related_products] = extract_related_products(product_data)
    end
    
    # Weight, dimensions, etc.
    result.merge!(extract_packaging_info(doc, product_data))
    
    # Videos
    result[:videos] = extract_videos(doc, product_data)
    
    # Manuals
    result[:manuals] = extract_manuals(doc, product_data)
    
    result
  end
  
  private
  
  def fetch_with_proxy(url)
    ProxyRotator.with_proxy_retry do |proxy|
      uri = URI.parse(url)
      proxy_uri = URI.parse(proxy)
      
      Net::HTTP.start(uri.host, uri.port, 
        proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password) do |http|
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)
        response.body
      end
    end
  end
  
  def extract_json_ld(doc)
    doc.css('script[type="application/ld+json"]').each do |script|
      begin
        data = JSON.parse(script.text)
        return data if data['@type'] == 'Product'
      rescue JSON::ParserError
        next
      end
    end
    nil
  end
  
  def extract_set_items(product_data, doc)
    possible_paths = [
      product_data&.dig('productSetSection', 'items'),
      product_data&.dig('setSection', 'items'),
      product_data&.dig('setItems'),
      product_data&.dig('productSet', 'items')
    ]
    
    items = []
    possible_paths.each do |path|
      if path.is_a?(Array) && path.any?
        items = path.map { |item| item['itemNo'] || item['itemNoGlobal'] || item }
                    .compact
                    .select { |item_no| item_no.match?(/^[0-9a-zA-Z]+$/) }
        break if items.any?
      end
    end
    
    # Если не нашли в JSON, пробуем HTML
    if items.empty?
      doc.css('.pip-product-set-section, .pip-set-items').each do |section|
        section.css('[data-item-no], .pip-item-no').each do |el|
          item_no = el['data-item-no'] || el.text.strip
          items << item_no if item_no.match?(/^[0-9a-zA-Z]+$/)
        end
      end
    end
    
    items.uniq
  end
  
  def extract_bundle_items(product_data, doc)
    # Аналогично extract_set_items
    # ...
  end
  
  def extract_related_products(product_data)
    product_data&.dig('addOns', 'addOns')&.flat_map do |addon|
      addon['items']&.select { |item| item['itemType'] == 'ART' }
                  &.map { |item| item['itemNo'] }
                  &.compact || []
    end || []
  end
  
  def extract_packaging_info(doc, product_data)
    result = {}
    
    # Извлекаем информацию об упаковке из productData или HTML
    packaging = product_data&.dig('stockcheckSection', 'packagingProps', 'packages')
    
    if packaging.is_a?(Array)
      total_weight = packaging.sum { |pkg| pkg['weight'] || 0 }
      result[:weight] = total_weight
      
      # Первая упаковка для netWeight
      first_pkg = packaging.first
      result[:net_weight] = first_pkg&.dig('netWeight') || 0
      
      # Объем и размеры
      result[:package_volume] = first_pkg&.dig('volume') || 0
      
      if first_pkg&.dig('measurements')
        dims = first_pkg['measurements']
        result[:package_dimensions] = "#{dims['width']} × #{dims['height']} × #{dims['length']}"
      end
    end
    
    result
  end
  
  def extract_videos(doc, product_data)
    videos = []
    
    # Из productData
    video_section = product_data&.dig('videoSection') || product_data&.dig('mediaSection')
    if video_section
      # Обработка видео из JSON
    end
    
    # Из HTML
    doc.css('iframe[src*="youtube"], iframe[src*="vimeo"], video source').each do |el|
      src = el['src'] || el['data-src']
      videos << src if src.present?
    end
    
    videos.uniq
  end
  
  def extract_manuals(doc, product_data)
    manuals = []
    
    # Из productData
    attachments = product_data&.dig('productInformationSection', 'attachments', 'manual')
    manuals.concat(Array(attachments)) if attachments
    
    # Из HTML
    doc.css('a[href*="manual"], a[href*="instruction"]').each do |link|
      href = link['href']
      manuals << href if href.present?
    end
    
    manuals.uniq
  end
end
```

### 2. Парсинг страницы товара IKEA Lithuania

```ruby
# app/lib/lt_details_fetcher.rb
class LtDetailsFetcher
  SEARCH_URL = 'https://www.ikea.lt/ru/search/?q='
  
  def self.fetch(item_no)
    new.fetch(item_no)
  end
  
  def fetch(item_no)
    # Поиск товара
    search_url = "#{SEARCH_URL}#{item_no}"
    search_html = fetch_with_proxy(search_url)
    search_doc = Nokogiri::HTML(search_html)
    
    # Находим ссылку на товар
    product_link = search_doc.css('.js-variant-result .card-body .itemInfo a').first
    return { translated: false } unless product_link
    
    href = product_link['href']
    href = "https://www.ikea.lt#{href}" unless href.start_with?('http')
    
    # Загружаем страницу товара
    product_html = fetch_with_proxy(href)
    product_doc = Nokogiri::HTML(product_html)
    
    result = { translated: true }
    
    # Название товара
    name = product_doc.css('h1 .itemFacts').text.strip
    result[:name] = clean_product_name(name) if name.present?
    
    # Материалы
    material_text = product_doc.css('#materials-details').inner_html
    result[:material_text] = material_text if material_text.present?
    
    # Детали товара
    good_text = product_doc.css('#good-details').inner_html
    result[:good_text] = good_text if good_text.present?
    
    # Описание
    details_text = product_doc.css('.product-details-content').inner_html
    result[:details_text] = details_text if details_text.present?
    
    result
  end
  
  private
  
  def clean_product_name(name)
    # Удаляем дополнительную информацию после запятой
    markers = [
      /\s*,\s*\d+\s*(предм|шт|штук|item|items|szt|sztuk|szt\.)/i,
      /\s*,\s*\d+\s*(x|×)\s*\d+/i,
      /\s*,\s*(цвет|в цвете|цвета):/i
    ]
    
    first_comma = name.index(',')
    if first_comma
      after_comma = name[first_comma..-1]
      markers.each do |marker|
        if marker.match?(after_comma)
          return name[0...first_comma].strip
        end
      end
    end
    
    name.strip
  end
  
  def fetch_with_proxy(url)
    ProxyRotator.with_proxy_retry do |proxy|
      # HTTP запрос через прокси
      # ...
    end
  end
end
```

---

## 🌍 Сервисы перевода

### 1. MyMemory Translation (Основной)

**Важно:** Для категорий используется ТОЛЬКО MyMemory (без fallback). Для товаров используется MyMemory → LibreTranslate → Google Translate.

```ruby
# app/services/translation_service.rb
class TranslationService
  MYMEMORY_API_URL = 'https://api.mymemory.translated.net/get'
  
  def self.translate_with_my_memory(text, target_lang: 'ru', source_lang: 'pl')
    return '' if text.blank?
    
    response = HTTParty.get(
      MYMEMORY_API_URL,
      query: {
        q: text.strip,
        langpair: "#{source_lang}|#{target_lang}",
        de: 'your_email@example.com'  # Required для некоторых запросов
      },
      timeout: 10
    )
    
    if response.success?
      translated_text = response.dig('responseData', 'translatedText')
      return translated_text if translated_text.present?
    end
    
    raise "MyMemory translation failed: #{response.code}"
  rescue => e
    Rails.logger.warn("MyMemory translation error: #{e.message}")
    raise
  end
end
```

### 2. LibreTranslate (Fallback)

```ruby
# app/services/libre_translate_service.rb
class LibreTranslateService
  SERVERS = [
    'https://libretranslate.de/translate',
    'https://libretranslate.com/translate'
  ].freeze
  
  def self.translate(text, target_lang: 'ru', source_lang: 'pl')
    return '' if text.blank?
    
    SERVERS.each do |server_url|
      begin
        response = HTTParty.post(
          server_url,
          body: {
            q: text.strip,
            source: source_lang,
            target: target_lang,
            format: 'text'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' },
          timeout: 10
        )
        
        if response.success?
          translated_text = response['translatedText']
          return translated_text if translated_text.present?
        end
      rescue => e
        Rails.logger.warn("LibreTranslate server #{server_url} failed: #{e.message}")
        next
      end
    end
    
    raise "All LibreTranslate servers failed"
  end
end
```

### 3. Google Cloud Translate (Последний fallback)

```ruby
# app/services/google_translate_service.rb
require 'google/cloud/translate'

class GoogleTranslateService
  def self.translate(text, target_lang: 'ru')
    return '' if text.blank?
    
    translate_client = Google::Cloud::Translate.translation_v2(
      project_id: ENV['GCLOUD_PROJECT'],
      credentials: ENV['GOOGLE_APPLICATION_CREDENTIALS']
    )
    
    translation = translate_client.translate(
      text,
      to: target_lang
    )
    
    translation.text
  rescue => e
    Rails.logger.error("Google Translate error: #{e.message}")
    raise
  end
end
```

### 4. Универсальный сервис перевода

**Примечание:** Этот сервис используется для товаров. Для категорий используется только MyMemory (см. CategoryService).

```ruby
# app/services/translation_service.rb
class TranslationService
  def self.translate(text, target_lang: 'ru', source_lang: 'pl')
    return '' if text.blank?
    
    # Кэширование переводов
    cached = TranslationCache.find_by(
      text: text.strip,
      target_language: target_lang,
      source_language: source_lang
    )
    return cached.translated_text if cached
    
    # Пробуем сервисы по очереди (только для товаров)
    translated = nil
    
    # 1. MyMemory
    begin
      translated = translate_with_my_memory(text, target_lang, source_lang)
    rescue => e
      Rails.logger.warn("MyMemory failed: #{e.message}")
      
      # 2. LibreTranslate
      begin
        translated = LibreTranslateService.translate(text, target_lang: target_lang, source_lang: source_lang)
      rescue => e2
        Rails.logger.warn("LibreTranslate failed: #{e2.message}")
        
        # 3. Google Translate
        begin
          translated = GoogleTranslateService.translate(text, target_lang: target_lang)
        rescue => e3
          Rails.logger.error("All translation services failed: #{e3.message}")
          return text  # Возвращаем оригинал
        end
      end
    end
    
    # Сохраняем в кэш
    TranslationCache.create!(
      text: text.strip,
      target_language: target_lang,
      source_language: source_lang,
      translated_text: translated
    )
    
    translated
  end
  
  private
  
  def self.translate_with_my_memory(text, target_lang, source_lang)
    # ... (см. выше)
  end
end
```

# Модель для кэширования переводов
# app/models/translation_cache.rb
class TranslationCache < ApplicationRecord
  validates :text, presence: true
  validates :target_language, presence: true
  validates :source_language, presence: true
  validates :translated_text, presence: true
  
  validates :text, uniqueness: { scope: [:target_language, :source_language] }
end
```

---

## 🚚 Расчет доставки

```ruby
# app/services/delivery_service.rb
class DeliveryService
  # Расчет доставки для товара
  def self.calculate_product_delivery(weight:, is_parcel: false, order_value: 0, is_ikea_family: true, is_weekend: false)
    return { success: false, error: 'Необходимо указать вес товара' } if weight.blank? || weight <= 0
    
    # Выбор типа доставки
    delivery_type, delivery_name, delivery_description, reason = determine_delivery_type(
      weight: weight,
      is_parcel: is_parcel
    )
    
    # Расчет стоимости
    cost = calculate_cost(
      weight: weight,
      delivery_type: delivery_type,
      is_ikea_family: is_ikea_family,
      order_value: order_value,
      is_weekend: is_weekend
    )
    
    {
      success: true,
      data: {
        selected_type: {
          id: delivery_type,
          name: delivery_name,
          description: delivery_description,
          reason: reason
        },
        cost: cost
      }
    }
  end
  
  private
  
  def self.determine_delivery_type(weight:, is_parcel:)
    if is_parcel
      ['gls_point', 'Доставка в Пункт Оdbioru GLS', 'Доставка в выбранный Пункт Оdbioru GLS', 'Посылка - доставка в пункт отбора']
    elsif weight <= 200
      ['without_carry', 'Доставка без заноса', 'Доставка до первой архитектурной преграды', 'Вес до 200 кг - доставка без заноса']
    else
      ['with_carry', 'Доставка с заносом', 'Доставка с заносом в указанное помещение', 'Вес больше 200 кг - доставка с заносом']
    end
  end
  
  def self.calculate_cost(weight:, delivery_type:, is_ikea_family:, order_value:, is_weekend:)
    case delivery_type
    when 'with_carry'
      calculate_with_carry_cost(weight, is_ikea_family, is_weekend)
    when 'without_carry'
      calculate_without_carry_cost(weight, is_ikea_family, is_weekend)
    when 'gls_point'
      calculate_gls_point_cost(order_value, is_ikea_family)
    else
      0
    end
  end
  
  def self.calculate_with_carry_cost(weight, is_ikea_family, is_weekend)
    # Реальные диапазоны веса и цены для доставки с заносом
    weight_ranges = [
      { min: 0, max: 50, weekday: { family: 99, regular: 119 }, weekend: { family: 109, regular: 129 } },
      { min: 50, max: 100, weekday: { family: 159, regular: 179 }, weekend: { family: 169, regular: 189 } },
      { min: 100, max: 200, weekday: { family: 199, regular: 219 }, weekend: { family: 209, regular: 229 } },
      { min: 200, max: 400, weekday: { family: 299, regular: 319 }, weekend: { family: 309, regular: 329 } },
      { min: 400, max: 600, weekday: { family: 499, regular: 519 }, weekend: { family: 509, regular: 529 } },
      { min: 600, max: 1000, weekday: { family: 599, regular: 619 }, weekend: { family: 609, regular: 629 } }
    ]
    
    range = weight_ranges.find { |r| weight >= r[:min] && weight <= r[:max] }
    
    unless range
      # Для веса больше 1000 кг используем специальный расчет
      return calculate_heavy_weight_cost(weight, is_ikea_family, is_weekend)
    end
    
    prices = is_weekend ? range[:weekend] : range[:weekday]
    is_ikea_family ? prices[:family] : prices[:regular]
  end
  
  def self.calculate_without_carry_cost(weight, is_ikea_family, is_weekend)
    # Реальные диапазоны веса и цены для доставки без заноса
    weight_ranges = [
      { min: 0, max: 50, weekday: { family: 69, regular: 79 }, weekend: { family: 79, regular: 89 } },
      { min: 50, max: 100, weekday: { family: 99, regular: 109 }, weekend: { family: 109, regular: 119 } },
      { min: 100, max: 200, weekday: { family: 159, regular: 169 }, weekend: { family: 169, regular: 179 } }
    ]
    
    range = weight_ranges.find { |r| weight >= r[:min] && weight <= r[:max] }
    return 0 unless range
    
    prices = is_weekend ? range[:weekend] : range[:weekday]
    is_ikea_family ? prices[:family] : prices[:regular]
  end
  
  def self.calculate_gls_point_cost(order_value, is_ikea_family)
    # GLS пункт - фиксированная цена (обычно бесплатно или минимальная)
    # В реальном проекте возвращает 0, но можно настроить по необходимости
    0
  end
  
  def self.calculate_heavy_weight_cost(weight, is_ikea_family, is_weekend)
    # Для веса больше 1000 кг суммируем соответствующие диапазоны
    total_cost = 0
    remaining_weight = weight
    
    ranges = [
      { max: 1000, cost: is_weekend ? 629 : 619 },
      { max: 600, cost: is_weekend ? 529 : 519 },
      { max: 400, cost: is_weekend ? 329 : 319 },
      { max: 200, cost: is_weekend ? 229 : 219 },
      { max: 100, cost: is_weekend ? 189 : 179 },
      { max: 50, cost: is_weekend ? 129 : 119 }
    ]
    
    ranges.each do |range|
      if remaining_weight > range[:max]
        additional_weight = remaining_weight - range[:max]
        additional_ranges = (additional_weight.to_f / range[:max]).ceil
        total_cost += additional_ranges * range[:cost]
        remaining_weight = range[:max]
      end
    end
    
    total_cost
  end
end
```

---

## ⏰ Планировщик задач

### Использование Sidekiq для background jobs

```ruby
# Gemfile
gem 'sidekiq'
gem 'sidekiq-cron'  # Для cron-задач

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

# config/schedule.yml (для sidekiq-cron)
sync_categories:
  cron: '0 0 */5 * *'  # Каждые 5 дней в полночь
  class: SyncCategoriesJob

sync_products:
  cron: '0 1 */5 * *'  # Каждые 5 дней в 1:00
  class: SyncProductsJob

update_offers:
  cron: '0 6 * * *'  # Ежедневно в 6:00
  class: UpdateOffersJob

download_images:
  cron: '0 3 */5 * *'  # Каждые 5 дней в 3:00
  class: DownloadImagesJob
```

### Jobs

```ruby
# app/jobs/sync_categories_job.rb
class SyncCategoriesJob < ApplicationJob
  queue_as :default
  
  def perform
    result = CategoryService.sync_categories
    TelegramNotifier.notify("✅ Синхронизация категорий завершена. Создано: #{result[:created]}, Обновлено: #{result[:updated]}")
  rescue => e
    TelegramNotifier.notify("❌ Ошибка синхронизации категорий: #{e.message}")
    raise
  end
end

# app/jobs/sync_products_job.rb
class SyncProductsJob < ApplicationJob
  queue_as :default
  
  def perform
    limit = ENV['PRODUCTS_LIMIT']&.to_i
    per_category = ENV['PRODUCTS_PER_CATEGORY']&.to_i
    
    result = ProductService.sync_products(limit: limit, products_per_category: per_category)
    TelegramNotifier.notify("✅ Синхронизация товаров завершена. Создано: #{result[:created]}, Обновлено: #{result[:updated]}")
  rescue => e
    TelegramNotifier.notify("❌ Ошибка синхронизации товаров: #{e.message}")
    raise
  end
end

# app/jobs/update_offers_job.rb
class UpdateOffersJob < ApplicationJob
  queue_as :default
  
  def perform
    result = OffersService.update_offers
    TelegramNotifier.notify("✅ Обновление офферов завершено. Обновлено: #{result[:updated]}")
  rescue => e
    TelegramNotifier.notify("❌ Ошибка обновления офферов: #{e.message}")
    raise
  end
end
```

---

## 🔌 API Endpoints приложения

### Контроллеры

```ruby
# app/controllers/api/products_controller.rb
class Api::ProductsController < ApplicationController
  before_action :authenticate_token, except: [:bestsellers, :popular]
  
  def bestsellers
    products = Product.bestsellers
                     .order(updated_at: :desc)
                     .page(params[:page])
                     .per(params[:limit] || 50)
    
    render json: {
      total: products.total_count,
      page: params[:page] || 1,
      limit: params[:limit] || 50,
      pages: products.total_pages,
      data: products.map { |p| product_json(p) }
    }
  end
  
  def popular
    products = Product.popular
                     .order(updated_at: :desc)
                     .page(params[:page])
                     .per(params[:limit] || 50)
    
    render json: {
      total: products.total_count,
      page: params[:page] || 1,
      limit: params[:limit] || 50,
      pages: products.total_pages,
      data: products.map { |p| product_json(p) }
    }
  end
  
  def index
    products = Product.all
                     .includes(:category)
                     .order(updated_at: :desc)
                     .page(params[:page])
                     .per(params[:limit] || 50)
    
    render json: {
      total: products.total_count,
      page: params[:page] || 1,
      limit: params[:limit] || 50,
      pages: products.total_pages,
      data: products.map { |p| product_json(p) }
    }
  end
  
  def show
    product = Product.find_by(sku: params[:id])
    
    if product
      render json: product_json(product, detailed: true)
    else
      render json: { error: 'Product not found' }, status: :not_found
    end
  end
  
  private
  
  def product_json(product, detailed: false)
    json = {
      sku: product.sku,
      name: product.name,
      name_ru: product.name_ru,
      item_no: product.item_no,
      url: product.url,
      price: product.price,
      weight: product.weight,
      delivery_type: product.delivery_type,
      delivery_name: product.delivery_name,
      delivery_cost: product.delivery_cost,
      category_id: product.category_id,
      category_name: product.category&.translated_name || product.category&.name || ''
    }
    
    if detailed
      json.merge!(
        images: product.images,
        local_images: product.local_images,
        content: product.content,
        content_ru: product.content_ru,
        material_info: product.material_info,
        material_info_ru: product.material_info_ru,
        dimensions: product.dimensions,
        package_dimensions: product.package_dimensions,
        variants: product.variants,
        set_items: product.set_items,
        bundle_items: product.bundle_items,
        related_products: product.related_products
      )
    end
    
    json
  end
  
  def authenticate_token
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token
    
    begin
      decoded = JWT.decode(token, ENV['JWT_SECRET'], true, algorithm: 'HS256')
      @current_user = User.find(decoded[0]['user_id'])
    rescue JWT::DecodeError
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end
end

# app/controllers/api/categories_controller.rb
class Api::CategoriesController < ApplicationController
  def index
    categories = Category.not_deleted
                        .order(:name)
    
    render json: build_category_tree(categories)
  end
  
  def show
    category = Category.find_by(ikea_id: params[:id])
    
    if category
      render json: {
        id: category.ikea_id,
        name: category.name,
        translated_name: category.translated_name,
        url: category.url,
        parent_ids: category.parent_ids,
        products_count: category.products.count
      }
    else
      render json: { error: 'Category not found' }, status: :not_found
    end
  end
  
  private
  
  def build_category_tree(categories)
    # Построение дерева категорий
    # ...
  end
end

# app/controllers/api/auth_controller.rb
class Api::AuthController < ApplicationController
  def login
    user = User.find_by(username: params[:username])
    
    if user&.authenticate(params[:password]) && user.is_active?
      token = JWT.encode(
        { user_id: user.id, username: user.username, role: user.role },
        ENV['JWT_SECRET'],
        'HS256'
      )
      
      render json: { token: token, user: { id: user.id, username: user.username, role: user.role } }
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    post 'auth/login', to: 'auth#login'
    
    resources :products, only: [:index, :show] do
      collection do
        get 'bestsellers'
        get 'popular'
      end
    end
    
    resources :categories, only: [:index, :show]
    
    resources :filters, only: [:index]
    
    post 'delivery/calculate', to: 'delivery#calculate'
    
    resources :users, only: [:index, :show, :create, :update, :destroy]
    
    get 'export/yml', to: 'export#yml'
    get 'export/xls', to: 'export#xls'
    get 'export/dealby', to: 'export#dealby'
  end
end
```

---

## 🔐 Переменные окружения

### .env файл

```bash
# База данных
DATABASE_URL=postgresql://localhost:5432/ikea_development
# или для MongoDB
MONGODB_URI=mongodb://localhost:27017/ikea

# Rails
RAILS_ENV=development
SECRET_KEY_BASE=your-secret-key-base

# JWT
JWT_SECRET=your-jwt-secret-key

# Telegram
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_CHAT_ID=your-chat-id

# Google Cloud Translate (опционально, fallback)
GCLOUD_PROJECT=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json

# LibreTranslate (опционально, fallback)
LIBRETRANSLATE_API_URL=https://libretranslate.com/translate
LIBRETRANSLATE_API_KEY=your-api-key-if-needed

# MyMemory (не требует ключа, но можно указать для увеличения лимита)
MYMEMORY_API_KEY=your-api-key-optional

# Прокси (хранить в безопасном месте!)
PROXY_LIST=http://user:pass@host1:port,http://user:pass@host2:port,http://user:pass@host3:port

# Лимиты для синхронизации
PRODUCTS_LIMIT=2000
PRODUCTS_PER_CATEGORY=10

# Redis (для Sidekiq)
REDIS_URL=redis://localhost:6379/0

# URL магазина (для экспорта)
SHOP_URL=https://www.ikea.com/pl/pl/
```

### Использование в Rails

```ruby
# config/application.rb
config.before_configuration do
  env_file = File.join(Rails.root, 'config', 'application.yml')
  if File.exist?(env_file)
    config = YAML.load(File.read(env_file))[Rails.env]
    config.each { |key, value| ENV[key.to_s] = value.to_s } if config
  end
end

# Или используйте гем 'dotenv-rails'
# Gemfile
gem 'dotenv-rails', groups: [:development, :test]
```

---

## 📚 Зависимости и гемы

### Gemfile

```ruby
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.0'

# Rails
gem 'rails', '~> 7.0'

# База данных
gem 'pg', '~> 1.4'  # PostgreSQL
# или
gem 'mongoid', '~> 8.0'  # MongoDB

# HTTP клиент
gem 'httparty'
gem 'faraday'  # Альтернатива

# Парсинг HTML
gem 'nokogiri'

# Браузерная автоматизация (для получения x-client-id)
gem 'selenium-webdriver'
# или более легковесная альтернатива
gem 'mechanize'

# Background jobs
gem 'sidekiq'
gem 'sidekiq-cron'

# JWT
gem 'jwt'

# Пагинация
gem 'kaminari'

# Валидация
gem 'bcrypt', '~> 3.1.7'

# Переменные окружения
gem 'dotenv-rails'

# Логирование
gem 'logger'

# Утилиты
gem 'json'
gem 'uri'
gem 'net/http'
```

### Установка

```bash
bundle install
```

---

## 🔄 Миграция данных

### Из MongoDB в PostgreSQL

```ruby
# lib/tasks/migrate_from_mongodb.rake
namespace :db do
  desc 'Migrate data from MongoDB to PostgreSQL'
  task migrate_from_mongodb: :environment do
    require 'mongo'
    
    # Подключение к MongoDB
    mongo_client = Mongo::Client.new(ENV['MONGODB_URI'])
    mongo_db = mongo_client.database
    
    # Миграция категорий
    puts "Migrating categories..."
    mongo_db['categories'].find.each do |mongo_category|
      Category.create!(
        ikea_id: mongo_category['id'],
        unique_id: mongo_category['uniqueId'],
        name: mongo_category['name'],
        translated_name: mongo_category['translatedName'],
        url: mongo_category['url'],
        remote_image_url: mongo_category['remoteImageUrl'],
        local_image_path: mongo_category['localImagePath'],
        parent_ids: mongo_category['parentIds'] || [],
        is_deleted: mongo_category['isDeleted'] || false,
        is_important: mongo_category['isImportant'] || false,
        is_popular: mongo_category['isPopular'] || false,
        translated: mongo_category['translated'] || false,
        created_at: mongo_category['createdAt'],
        updated_at: mongo_category['updatedAt']
      )
    end
    
    # Миграция товаров
    puts "Migrating products..."
    mongo_db['products'].find.each do |mongo_product|
      Product.create!(
        sku: mongo_product['sku'],
        unique_id: mongo_product['uniqueId'],
        name: mongo_product['name'],
        name_ru: mongo_product['nameRu'],
        collection: mongo_product['collection'],
        item_no: mongo_product['itemNo'],
        url: mongo_product['url'],
        variants: mongo_product['variants'] || [],
        related_products: mongo_product['relatedProducts'] || [],
        set_items: mongo_product['setItems'] || [],
        bundle_items: mongo_product['bundleItems'] || [],
        images: mongo_product['images'] || [],
        local_images: mongo_product['localImages'] || [],
        images_total: mongo_product['imagesTotal'] || 0,
        images_stored: mongo_product['imagesStored'] || 0,
        images_incomplete: mongo_product['imagesIncomplete'] || false,
        manuals: mongo_product['manuals'] || [],
        videos: mongo_product['videos'] || [],
        price: mongo_product['price'],
        home_delivery: mongo_product['homeDelivery'],
        content: mongo_product['content'],
        content_ru: mongo_product['contentRu'],
        good_info: mongo_product['goodInfo'],
        good_info_ru: mongo_product['goodInfoRu'],
        material_info: mongo_product['materialInfo'],
        material_info_ru: mongo_product['materialInfoRu'],
        weight: mongo_product['weight'],
        net_weight: mongo_product['netWeight'],
        package_volume: mongo_product['packageVolume'],
        package_dimensions: mongo_product['packageDimensions'],
        dimensions: mongo_product['dimensions'],
        quantity: mongo_product['quantity'] || 0,
        is_parcel: mongo_product['isParcel'] || false,
        translated: mongo_product['translated'] || false,
        is_bestseller: mongo_product['isBestseller'] || false,
        is_popular: mongo_product['isPopular'] || false,
        category_id: mongo_product['categoryId'],
        delivery_type: mongo_product['deliveryType'],
        delivery_name: mongo_product['deliveryName'],
        delivery_cost: mongo_product['deliveryCost'],
        delivery_reason: mongo_product['deliveryReason'],
        created_at: mongo_product['createdAt'],
        updated_at: mongo_product['updatedAt']
      )
    end
    
    puts "Migration completed!"
  end
end
```

**Запуск:**
```bash
rails db:migrate_from_mongodb
```

---

## 📝 Дополнительные замечания

### 1. Обработка ошибок

Все сервисы должны иметь обработку ошибок и логирование:

```ruby
rescue => e
  Rails.logger.error("Error in #{self.class.name}: #{e.message}")
  Rails.logger.error(e.backtrace.join("\n"))
  raise
end
```

### 2. Логирование опасных операций

Рекомендуется добавить логирование для критических операций (удаление, очистка данных):

```ruby
# config/initializers/dangerous_operations_logger.rb
module DangerousOperationsLogger
  def self.included(base)
    base.before_destroy :log_dangerous_operation
  end
  
  private
  
  def log_dangerous_operation
    Rails.logger.warn("⚠️ DANGEROUS OPERATION: #{self.class.name}##{id} is being deleted")
    # Отправка в Telegram
    TelegramNotifier.notify("⚠️ *DANGEROUS OPERATION*: #{self.class.name}##{id} is being deleted")
  end
end

# app/models/product.rb
class Product < ApplicationRecord
  include DangerousOperationsLogger
  # ...
end
```

### 3. Тестирование

Рекомендуется написать тесты для всех сервисов:

```ruby
# spec/services/product_service_spec.rb
RSpec.describe ProductService do
  describe '.sync_products' do
    it 'creates new products' do
      # ...
    end
  end
end
```

### 4. Производительность

- Используйте `find_each` вместо `all` для больших коллекций
- Используйте `includes` для eager loading связей
- Используйте background jobs для долгих операций
- Кэшируйте переводы в базе данных

### 5. Безопасность

- Храните прокси-данные и API ключи в переменных окружения
- Используйте strong parameters в контроллерах
- Валидируйте все входные данные
- Используйте HTTPS для всех внешних запросов

### 6. Мониторинг и логирование

- Реализуйте мониторинг памяти при обработке больших объемов данных
- Логируйте все критические операции
- Настройте уведомления в Telegram при ошибках
- Отслеживайте производительность запросов к внешним API

---

## ✅ Чеклист миграции

- [ ] Настроить Rails приложение
- [ ] Создать модели (Product, Category, Filter, FilterValue, User)
- [ ] Настроить базу данных (PostgreSQL или MongoDB)
- [ ] Реализовать сервисы (IkeaApiService, ProductService, CategoryService)
- [ ] Реализовать парсеры (PlDetailsFetcher, LtDetailsFetcher)
- [ ] Реализовать сервисы перевода
- [ ] Реализовать расчет доставки
- [ ] Настроить прокси-ротацию
- [ ] Настроить Sidekiq и background jobs
- [ ] Создать API контроллеры
- [ ] Настроить JWT авторизацию
- [ ] Мигрировать данные из MongoDB (если нужно)
- [ ] Настроить переменные окружения
- [ ] Написать тесты
- [ ] Настроить деплой

---

---

## 📊 Важные замечания по реализации

### Критические моменты:

1. **Расчет доставки**: Используются реальные диапазоны веса с фиксированными ценами для IKEA Family и обычных пользователей, а также для выходных дней. См. раздел [Расчет доставки](#расчет-доставки).

2. **Определение isParcel**: Товары с весом <= 30 кг автоматически считаются посылками (parcel) и используют доставку GLS.

3. **Перевод категорий**: Используется ТОЛЬКО MyMemory (без fallback). Если перевод не получен, сохраняется существующий перевод из БД.

4. **Обработка ошибок БД**: Все операции сохранения должны иметь ретраи при разрывах соединения с автоматическим переподключением.

5. **Мониторинг памяти**: При обработке больших объемов данных необходимо отслеживать использование памяти и запускать сборку мусора при превышении лимитов.

6. **Прокси-ротация**: Используется round-robin для новых запросов с сохранением индекса для ретраев при 403 ошибках.

---

**Удачи с миграцией! 🚀**

