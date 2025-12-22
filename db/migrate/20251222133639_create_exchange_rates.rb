class CreateExchangeRates < ActiveRecord::Migration[7.1]
  def change
    create_table :exchange_rates do |t|
      t.date :date, null: false
      t.string :currency_code, null: false
      t.decimal :rate, precision: 10, scale: 4, null: false
      t.decimal :official_rate, precision: 10, scale: 4
      t.integer :scale, default: 1

      t.timestamps
    end
    
    add_index :exchange_rates, :currency_code
    add_index :exchange_rates, [:date, :currency_code], unique: true
  end
end
