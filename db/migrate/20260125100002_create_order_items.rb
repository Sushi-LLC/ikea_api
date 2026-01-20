class CreateOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :order_items do |t|
      t.belongs_to :order, null: false, foreign_key: true, index: true
      t.string :product_sku, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :price, precision: 12, scale: 2

      t.index :product_sku
      t.index [:order_id, :product_sku], unique: true

      t.timestamps
    end
  end
end
