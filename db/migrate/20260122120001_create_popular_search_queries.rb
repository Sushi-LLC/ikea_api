class CreatePopularSearchQueries < ActiveRecord::Migration[7.1]
  def change
    create_table :popular_search_queries do |t|
      t.string :query, null: false
      t.integer :weight, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :popular_search_queries, :query
    add_index :popular_search_queries, :active
  end
end
