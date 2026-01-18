class CreateCarts < ActiveRecord::Migration[7.1]
  def change
    create_table :carts do |t|
      t.string :guest_token, null: false
      t.datetime :expires_at, null: false
      t.bigint :promo_code_id

      t.timestamps
    end

    add_index :carts, :guest_token, unique: true
    add_index :carts, :expires_at
  end
end
