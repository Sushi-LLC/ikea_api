# Сервис для перевода через Google Cloud Translate
# Требует настройки: GCLOUD_PROJECT и GOOGLE_APPLICATION_CREDENTIALS

class GoogleTranslateService
  def self.translate(text, target_lang: 'ru')
    return '' if text.blank?
    
    unless ENV['GCLOUD_PROJECT'].present? && ENV['GOOGLE_APPLICATION_CREDENTIALS'].present?
      raise "Google Cloud Translate not configured"
    end
    
    require 'google/cloud/translate'
    
    translate_client = Google::Cloud::Translate.translation_v2(
      project_id: ENV['GCLOUD_PROJECT'],
      credentials: ENV['GOOGLE_APPLICATION_CREDENTIALS']
    )
    
    translation = translate_client.translate(
      text,
      to: target_lang
    )
    
    translation.text
  rescue => e
    Rails.logger.error("Google Translate error: #{e.message}")
    raise
  end
end

