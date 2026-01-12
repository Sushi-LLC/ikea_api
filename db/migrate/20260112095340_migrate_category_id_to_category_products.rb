class MigrateCategoryIdToCategoryProducts < ActiveRecord::Migration[7.1]
  def up
    # Переносим все существующие связи из category_id в category_products
    # Используем SQL для эффективности
    execute <<-SQL
      INSERT INTO category_products (product_id, category_id, created_at, updated_at)
      SELECT id, category_id, created_at, updated_at
      FROM products
      WHERE category_id IS NOT NULL AND category_id != ''
      ON CONFLICT (product_id, category_id) DO NOTHING;
    SQL
    
    puts "✅ Перенесено связей: #{CategoryProduct.count}"
  end
  
  def down
    # При откате удаляем все связи
    CategoryProduct.delete_all
  end
end
