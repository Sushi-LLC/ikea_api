class AddRatingCacheToProducts < ActiveRecord::Migration[7.1]
  def change
    change_table :products do |t|
      t.decimal :rating_avg, precision: 4, scale: 2, null: false, default: 0
      t.decimal :rating_weighted, precision: 5, scale: 2, null: false, default: 0
      t.integer :rating_count, null: false, default: 0
      t.datetime :rating_updated_at
    end
  end
end
