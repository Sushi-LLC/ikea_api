class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews do |t|
      t.belongs_to :user, null: false, foreign_key: true, index: true
      t.string :product_sku, null: false
      t.belongs_to :order, foreign_key: true, index: true
      t.integer :rating, null: false
      t.text :body, null: false
      t.integer :status, null: false, default: 0
      t.datetime :published_at
      t.text :admin_note
      t.boolean :pinned, null: false, default: false
      t.boolean :excluded_from_rating, null: false, default: false

      t.index :product_sku
      t.index :status
      t.index [:user_id, :product_sku], unique: true

      t.timestamps
    end
  end
end
