class CreateReviewSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :review_settings do |t|
      t.decimal :helpful_weight_factor, precision: 5, scale: 4, null: false, default: "0.1"
      t.decimal :base_weight, precision: 5, scale: 2, null: false, default: "1.0"

      t.timestamps
    end
  end
end
