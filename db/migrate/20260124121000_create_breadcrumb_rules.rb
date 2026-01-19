class CreateBreadcrumbRules < ActiveRecord::Migration[7.1]
  def change
    create_table :breadcrumb_rules, if_not_exists: true do |t|
      t.string :entity_type, null: false
      t.integer :rule_type, null: false, default: 0
      t.jsonb :payload, default: {}
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    add_index :breadcrumb_rules, :entity_type, if_not_exists: true
    add_index :breadcrumb_rules, [:entity_type], unique: true, where: "active", if_not_exists: true
  end
end
