class AddExtendedAttributesToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :materials, :text
    add_column :products, :features, :text
    add_column :products, :care_instructions, :text
    add_column :products, :environmental_info, :text
    add_column :products, :short_description, :text
  end
end
