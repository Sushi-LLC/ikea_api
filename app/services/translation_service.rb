# Сервис для перевода текстов
require 'httparty'

class TranslationService
  MYMEMORY_API_URL = 'https://api.mymemory.translated.net/get'
  
  # Универсальный метод перевода (для продуктов)
  # Использует каскад: MyMemory → LibreTranslate → Google Translate
  def self.translate(text, target_lang: 'ru', source_lang: 'pl')
    return '' if text.blank?
    
    # Кэширование переводов
    cached = TranslationCache.find_by(
      text: text.strip,
      target_language: target_lang,
      source_language: source_lang
    )
    return cached.translated_text if cached
    
    # Пробуем сервисы по очереди (только для товаров)
    translated = nil
    
    # 1. MyMemory
    begin
      translated = translate_with_my_memory(text, target_lang: target_lang, source_lang: source_lang)
    rescue => e
      Rails.logger.warn("MyMemory failed: #{e.message}")
      
      # 2. LibreTranslate
      begin
        translated = LibreTranslateService.translate(text, target_lang: target_lang, source_lang: source_lang)
      rescue => e2
        Rails.logger.warn("LibreTranslate failed: #{e2.message}")
        
        # 3. Google Translate (если настроен)
        if ENV['GCLOUD_PROJECT'].present? && ENV['GOOGLE_APPLICATION_CREDENTIALS'].present?
          begin
            translated = GoogleTranslateService.translate(text, target_lang: target_lang)
          rescue => e3
            Rails.logger.error("All translation services failed: #{e3.message}")
            translated = text # Возвращаем оригинал
          end
        else
          Rails.logger.warn("Google Translate not configured, returning original text")
          translated = text
        end
      end
    end
    
    # Сохраняем в кэш
    if translated.present? && translated != text
      begin
        TranslationCache.find_or_create_by!(
          text: text.strip,
          target_language: target_lang,
          source_language: source_lang
        ) do |cache|
          cache.translated_text = translated
        end
      rescue ActiveRecord::RecordInvalid => e
        # Уже есть в кэше или ошибка валидации, игнорируем
        Rails.logger.debug("Translation cache error: #{e.message}")
      end
    end
    
    translated
  end
  
  # Перевод только через MyMemory (для категорий)
  def self.translate_with_my_memory(text, target_lang: 'ru', source_lang: 'pl')
    return '' if text.blank?
    
    # Проверяем кэш
    cached = TranslationCache.find_by(
      text: text.strip,
      target_language: target_lang,
      source_language: source_lang
    )
    return cached.translated_text if cached
    
    email = ENV.fetch('MYMEMORY_EMAIL', 'translations@ikea-api.local')
    
    response = HTTParty.get(
      MYMEMORY_API_URL,
      query: {
        q: text.strip,
        langpair: "#{source_lang}|#{target_lang}",
        de: email
      },
      timeout: 10
    )
    
    if response.success?
      translated_text = response.dig('responseData', 'translatedText')
      if translated_text.present? && translated_text != text.strip
        # Сохраняем в кэш
        begin
          TranslationCache.find_or_create_by!(
            text: text.strip,
            target_language: target_lang,
            source_language: source_lang
          ) do |cache|
            cache.translated_text = translated_text
          end
        rescue ActiveRecord::RecordInvalid => e
          # Уже есть в кэше или ошибка валидации, игнорируем
          Rails.logger.debug("Translation cache error: #{e.message}")
        end
        return translated_text
      end
    end
    
    raise "MyMemory translation failed: HTTP #{response.code}"
  rescue => e
    Rails.logger.warn("MyMemory translation error: #{e.message}")
    raise
  end
end

