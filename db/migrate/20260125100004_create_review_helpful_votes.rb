class CreateReviewHelpfulVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :review_helpful_votes do |t|
      t.belongs_to :review, null: false, foreign_key: true, index: true
      t.belongs_to :user, null: false, foreign_key: true, index: true

      t.index [:review_id, :user_id], unique: true

      t.timestamps
    end
  end
end
