class CreateCartItems < ActiveRecord::Migration[7.1]
  def change
    create_table :cart_items do |t|
      t.bigint :cart_id, null: false
      t.string :product_sku, null: false
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_index :cart_items, [:cart_id, :product_sku], unique: true
    add_index :cart_items, :product_sku
    add_foreign_key :cart_items, :carts
  end
end
