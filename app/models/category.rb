class Category < ApplicationRecord
  self.primary_key = 'ikea_id'
  
  validates :ikea_id, presence: true, uniqueness: true
  validates :name, presence: true
  
  # Старая связь (для обратной совместимости, будет удалена после миграции)
  has_many :products, foreign_key: :category_id, primary_key: :ikea_id
  
  # Новая связь many-to-many
  has_many :category_products, foreign_key: :category_id, primary_key: :ikea_id, dependent: :destroy
  has_many :products_through_categories, through: :category_products, source: :product
  
  serialize :parent_ids, coder: JSON
  
  scope :popular, -> { where(is_popular: true) }
  scope :active, -> { where(is_deleted: [false, nil]) }
  scope :not_deleted, -> { where(is_deleted: [false, nil]) }
  # Категории с цифровым кодом (ikea_id состоит только из цифр)
  scope :with_numeric_id, -> { where("ikea_id ~ '^[0-9]+$'") }
  # Верхнеуровневые категории (без родительских категорий)
  # Используем поле is_important для определения верхнеуровневых категорий
  # Также проверяем parent_ids на nil или пустой массив для совместимости
  scope :top_level, -> {
    where(
      "is_important = ? OR parent_ids IS NULL OR parent_ids::text = ? OR parent_ids::text = ? OR parent_ids::text = ?",
      true, '[]', '""', ''
    )
  }
  
  # Подсчет дочерних категорий (категории, у которых текущая категория в parent_ids)
  # Кэшируем результат для каждой категории
  def children_count
    return 0 unless ikea_id.present?
    
    Rails.cache.fetch("category_#{ikea_id}_children_count", expires_in: 30.minutes) do
      # Оптимизированный запрос - используем только COUNT без загрузки записей
      Category.where(
        "parent_ids::text LIKE ? OR parent_ids::text LIKE ?",
        "%\"#{ikea_id}\"%",  # JSON массив: ["parent_id"]
        "%#{ikea_id}%"      # Путь: "parent_id/child_id" или просто строка
      ).where.not(ikea_id: ikea_id) # Исключаем саму категорию
       .count
    end
  end

  # Получить дочерние категории
  def children
    return Category.none unless ikea_id.present?
    
    # Оптимизированный запрос - загружаем только нужные поля
    Category.select(:ikea_id, :name, :translated_name, :parent_ids, :is_popular, :is_deleted, :is_important)
            .where(
              "parent_ids::text LIKE ? OR parent_ids::text LIKE ?",
              "%\"#{ikea_id}\"%",
              "%#{ikea_id}%"
            )
            .where.not(ikea_id: ikea_id)
            .order(:name)
  end

  # Проверка, является ли категория родительской (имеет дочерние)
  def has_children?
    children_count > 0
  end

  # Проверка наличия продуктов в категории
  def has_products?
    products.exists?
  end

  # Проверка, является ли ID категории числовым
  def numeric_id?
    ikea_id.to_s.match?(/^\d+$/)
  end

  # Проверка, является ли ID категории UUID
  def uuid_id?
    ikea_id.to_s.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
  end

  # Класс для построения дерева категорий
  class << self
    def build_tree(categories = nil)
      categories ||= Category.select(:ikea_id, :name, :translated_name, :parent_ids, :is_popular, :is_deleted, :is_important)
                             .order(:name)
                             .to_a
      
      # Оптимизация: создаем индекс для быстрого поиска дочерних категорий
      # Используем Hash для O(1) поиска
      children_index = {}
      categories.each do |cat|
        parent_ids = self.normalize_parent_ids(cat.parent_ids)
        next unless parent_ids.present? && parent_ids.any?
        
        parent_ids.each do |parent_id|
          parent_key = parent_id.to_s
          children_index[parent_key] ||= []
          children_index[parent_key] << cat
        end
      end
      
      # Находим верхнеуровневые категории
      # Оптимизация: используем select вместо select + each для лучшей производительности
      top_level = categories.select do |c|
        parent_ids = self.normalize_parent_ids(c.parent_ids)
        c.is_important || 
        parent_ids.blank? || 
        parent_ids == [] || 
        (parent_ids.is_a?(Array) && parent_ids.empty?)
      end
      
      build_tree_recursive(top_level, children_index)
    end

    # Публичный метод для нормализации parent_ids (используется в контроллерах)
    def normalize_parent_ids(parent_ids)
      return [] if parent_ids.blank?
      
      # Если это уже массив, возвращаем как есть
      return parent_ids if parent_ids.is_a?(Array)
      
      # Если это строка JSON, парсим
      if parent_ids.is_a?(String)
        begin
          parsed = JSON.parse(parent_ids)
          return parsed if parsed.is_a?(Array)
          return [parsed] if parsed.present?
        rescue JSON::ParserError
          # Если не JSON, пробуем как простую строку
          return [parent_ids] if parent_ids.present?
        end
      end
      
      []
    end

    private

    def build_tree_recursive(parents, children_index)
      parents.map do |parent|
        # Используем индекс для быстрого поиска дочерних категорий
        children = children_index[parent.ikea_id.to_s] || []
        
        {
          category: parent,
          children: build_tree_recursive(children, children_index)
        }
      end
    end
  end
end
