class AddParentIdsIndexToCategories < ActiveRecord::Migration[7.1]
  def change
    # Добавляем expression index для быстрого поиска в JSON поле parent_ids
    # Используем функцию для преобразования в текст и создания индекса
    # Это ускорит поиск дочерних категорий через LIKE запросы
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_categories_on_parent_ids_text 
      ON categories USING gin (to_tsvector('simple', COALESCE(parent_ids::text, '')))
      WHERE parent_ids IS NOT NULL AND parent_ids::text != '[]' AND parent_ids::text != '';
    SQL
    
    # Альтернативный B-tree индекс для точного поиска
    add_index :categories, :parent_ids, 
              where: "parent_ids IS NOT NULL AND parent_ids::text != '[]' AND parent_ids::text != ''",
              name: 'index_categories_on_parent_ids_btree'
  end
end

