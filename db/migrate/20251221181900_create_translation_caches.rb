class CreateTranslationCaches < ActiveRecord::Migration[7.1]
  def change
    create_table :translation_caches do |t|
      t.text :text, null: false
      t.string :target_language, null: false, limit: 10
      t.string :source_language, null: false, limit: 10
      t.text :translated_text, null: false

      t.timestamps
    end

    add_index :translation_caches, [:text, :target_language, :source_language], 
              unique: true, name: 'index_translation_caches_on_text_and_languages'
  end
end
