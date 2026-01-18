class CreatePromoCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :promo_codes do |t|
      t.string :code, null: false
      t.string :name
      t.integer :discount_type, null: false
      t.decimal :discount_value, precision: 12, scale: 2, null: false
      t.boolean :active, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at

      t.timestamps
    end

    add_index :promo_codes, :code, unique: true
    add_index :promo_codes, [:active, :ends_at]
  end
end
