class AddPromoCodeFkToCarts < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :carts, :promo_codes
  end
end
