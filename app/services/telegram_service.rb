# Сервис для отправки уведомлений в Telegram
# Используем простой HTTP запрос к Telegram Bot API
require 'net/http'
require 'uri'

class TelegramService
  class << self
    def send_message(text, parse_mode: 'HTML')
      return unless bot_token.present? && chat_id.present?

      begin
        uri = URI("https://api.telegram.org/bot#{bot_token}/sendMessage")
        response = Net::HTTP.post_form(uri, {
          chat_id: chat_id,
          text: text,
          parse_mode: parse_mode
        })
        
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "Telegram API error: #{response.body}"
        end
      rescue => e
        Rails.logger.error "Telegram error: #{e.message}"
        # Не падаем, если Telegram недоступен
      end
    end

    def send_parser_started(task_type, limit: nil)
      message = "🚀 <b>Парсинг запущен</b>\n\n"
      message += "Тип: #{task_type_name(task_type)}\n"
      message += "Ограничение: #{limit || 'без ограничений'}\n"
      message += "Время: #{Time.current.strftime('%d.%m.%Y %H:%M:%S')}"
      
      send_message(message)
    end

    def send_parser_completed(task_type, stats)
      message = "✅ <b>Парсинг завершен</b>\n\n"
      message += "Тип: #{task_type_name(task_type)}\n"
      message += "Обработано: #{stats[:processed] || 0}\n"
      message += "Создано: #{stats[:created] || 0}\n"
      message += "Обновлено: #{stats[:updated] || 0}\n"
      message += "Ошибок: #{stats[:errors] || 0}\n"
      message += "Время выполнения: #{format_duration(stats[:duration] || 0)}"
      
      send_message(message)
    end

    def send_parser_error(task_type, error)
      message = "❌ <b>Ошибка парсинга</b>\n\n"
      message += "Тип: #{task_type_name(task_type)}\n"
      message += "Ошибка: #{error.message}\n"
      message += "Время: #{Time.current.strftime('%d.%m.%Y %H:%M:%S')}"
      
      send_message(message)
    end

    private

    def bot_token
      ENV['TELEGRAM_BOT_TOKEN']
    end

    def chat_id
      ENV['TELEGRAM_CHAT_ID']
    end

    def task_type_name(task_type)
      {
        'categories' => 'Категории',
        'products' => 'Продукты',
        'bestsellers' => 'Хиты продаж',
        'popular_categories' => 'Популярные категории',
        'category_images' => 'Картинки категорий',
        'product_images' => 'Картинки продуктов'
      }[task_type.to_s] || task_type.to_s
    end

    def format_duration(seconds)
      return '0 сек' if seconds.nil? || seconds.zero?
      
      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i
      secs = (seconds % 60).to_i
      
      parts = []
      parts << "#{hours} ч" if hours > 0
      parts << "#{minutes} мин" if minutes > 0
      parts << "#{secs} сек" if secs > 0
      
      parts.join(' ') || '0 сек'
    end
  end
end

