class CreatePromoCodeProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :promo_code_products do |t|
      t.bigint :promo_code_id, null: false
      t.string :product_sku, null: false

      t.timestamps
    end

    add_index :promo_code_products, [:promo_code_id, :product_sku], unique: true
    add_index :promo_code_products, :product_sku
    add_foreign_key :promo_code_products, :promo_codes
  end
end
