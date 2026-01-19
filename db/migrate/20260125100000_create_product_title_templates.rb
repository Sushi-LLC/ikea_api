class CreateProductTitleTemplates < ActiveRecord::Migration[7.1]
  def up
    create_table :product_title_templates do |t|
      t.string :key, null: false
      t.text :template_string
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :product_title_templates, :key, unique: true

    template_class = Class.new(ActiveRecord::Base) do
      self.table_name = "product_title_templates"
    end

    template_class.create!(
      key: "default_title",
      template_string: "{{name}} • {{collection}} • {{category}}",
      active: true
    )
    template_class.create!(
      key: "default_h1",
      template_string: "{{name}}",
      active: true
    )
  end

  def down
    drop_table :product_title_templates
  end
end
