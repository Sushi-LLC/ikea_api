class AddPhoneAuthTables < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :phone, :string
    add_index :users, :phone, unique: true

    create_table :verification_codes do |t|
      t.string :phone, null: false
      t.string :code, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :verification_codes, :phone
  end
end
