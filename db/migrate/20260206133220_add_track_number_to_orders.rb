class AddTrackNumberToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :track_number, :string
  end
end
