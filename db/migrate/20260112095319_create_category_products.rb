class CreateCategoryProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :category_products do |t|
      t.references :product, null: false, foreign_key: true
      t.string :category_id, null: false # ikea_id категории

      t.timestamps
    end
    
    # Индексы для быстрого поиска
    add_index :category_products, :category_id
    add_index :category_products, [:product_id, :category_id], unique: true, name: 'index_category_products_unique'
  end
end
