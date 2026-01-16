class CreateHomeBanners < ActiveRecord::Migration[7.1]
  def change
    create_table :home_banners do |t|
      t.integer :section, null: false, default: 0
      t.integer :variant, null: false, default: 0
      t.string :title
      t.string :subtitle
      t.string :category_id
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    
    add_index :home_banners, [:section, :active, :position]
    add_index :home_banners, :category_id
    add_foreign_key :home_banners, :categories, column: :category_id, primary_key: :ikea_id, on_delete: :nullify
  end
end
