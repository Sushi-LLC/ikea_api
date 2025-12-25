class AddRussianTranslationsToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :materials_ru, :text
    add_column :products, :features_ru, :text
    add_column :products, :care_instructions_ru, :text
    add_column :products, :environmental_info_ru, :text
    add_column :products, :short_description_ru, :text
    add_column :products, :designer_ru, :string
    add_column :products, :safety_info_ru, :text
    add_column :products, :good_to_know_ru, :text
  end
end
