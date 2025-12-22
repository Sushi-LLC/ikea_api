class CreateCalculatorSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :calculator_settings do |t|
      t.string :key, null: false
      t.text :value, null: false
      t.string :setting_type, null: false
      t.text :description

      t.timestamps
    end
    
    add_index :calculator_settings, :key, unique: true
  end
end
