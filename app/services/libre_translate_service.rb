# Сервис для перевода через LibreTranslate
require 'httparty'

class LibreTranslateService
  SERVERS = [
    'https://libretranslate.de/translate',
    'https://libretranslate.com/translate'
  ].freeze
  
  def self.translate(text, target_lang: 'ru', source_lang: 'pl')
    return '' if text.blank?
    
    SERVERS.each do |server_url|
      begin
        response = HTTParty.post(
          server_url,
          body: {
            q: text.strip,
            source: source_lang,
            target: target_lang,
            format: 'text'
          }.to_json,
          headers: { 
            'Content-Type' => 'application/json',
            'User-Agent' => ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
          },
          timeout: 10
        )
        
        if response.success?
          translated_text = response['translatedText']
          return translated_text if translated_text.present?
        end
      rescue => e
        Rails.logger.warn("LibreTranslate server #{server_url} failed: #{e.message}")
        next
      end
    end
    
    raise "All LibreTranslate servers failed"
  end
end

