class CreateFeedSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :feed_settings do |t|
      t.boolean :feeds_enabled, null: false, default: true
      t.integer :feed_access_mode, null: false, default: 0
      t.string :feed_token
      t.string :base_url, null: false, default: "https://example.com"
      t.string :currency_default, null: false, default: "BYN"
      t.string :store_name
      t.string :store_company
      t.string :store_platform_brand
      t.jsonb :availability_mapping, null: false, default: {
        "in_stock" => "in stock",
        "out_of_stock" => "out of stock",
        "preorder" => "preorder"
      }
      t.decimal :yml_delivery_cost, precision: 10, scale: 2
      t.integer :yml_delivery_days
      t.boolean :include_out_of_stock, null: false, default: false

      t.timestamps
    end
  end
end
