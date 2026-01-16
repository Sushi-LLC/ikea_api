class CreateSearchQueryLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :search_query_logs do |t|
      t.references :customer, foreign_key: { to_table: :users }, index: true
      t.string :query, null: false
      t.integer :results_count, default: 0, null: false
      t.string :clicked_product_sku

      t.timestamps
    end

    add_index :search_query_logs, :query
  end
end
