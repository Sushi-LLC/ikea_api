class TranslationCache < ApplicationRecord
  validates :text, presence: true
  validates :target_language, presence: true
  validates :source_language, presence: true
  validates :translated_text, presence: true
  
  validates :text, uniqueness: { scope: [:target_language, :source_language] }
end

