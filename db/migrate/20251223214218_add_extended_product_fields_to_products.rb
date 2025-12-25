class AddExtendedProductFieldsToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :designer, :string
    add_column :products, :safety_info, :text
    add_column :products, :good_to_know, :text
    add_column :products, :assembly_documents, :text # JSON массив ссылок на документы
  end
end
