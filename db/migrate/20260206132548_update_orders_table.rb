class UpdateOrdersTable < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :total_amount, :decimal, precision: 12, scale: 2
    add_column :orders, :delivery_price, :decimal, precision: 12, scale: 2
    add_column :orders, :discount_amount, :decimal, precision: 12, scale: 2
    add_reference :orders, :promo_code, foreign_key: true
    add_column :orders, :delivery_type, :string
    add_column :orders, :payment_method, :string
    add_column :orders, :full_name, :string
    add_column :orders, :phone, :string
    add_column :orders, :address_json, :jsonb, default: {}
  end
end
