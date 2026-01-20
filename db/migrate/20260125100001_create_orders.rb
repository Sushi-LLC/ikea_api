class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.belongs_to :user, null: false, foreign_key: true, index: true
      t.string :crm_external_id, index: true
      t.string :country
      t.integer :status, null: false, default: 0
      t.datetime :purchased_at

      t.timestamps
    end
  end
end
