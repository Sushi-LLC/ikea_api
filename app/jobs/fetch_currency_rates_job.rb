# Задача для получения курсов валют из API NBP и отправки уведомления в Telegram
class FetchCurrencyRatesJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "FetchCurrencyRatesJob: Starting currency rates fetch"
    
    begin
      rates = CurrencyRateService.fetch_rates
      
      # Форматируем сообщение для Telegram
      message = CurrencyRateService.format_rates_for_telegram(rates)
      
      # Отправляем уведомление в Telegram
      TelegramService.send_message(message, parse_mode: 'HTML')
      
      Rails.logger.info "FetchCurrencyRatesJob: Successfully fetched and sent currency rates"
      
      # Сохраняем курсы в кеш или базу данных (опционально)
      cache_currency_rates(rates)
      
    rescue => e
      error_message = "❌ <b>Ошибка получения курсов валют</b>\n\n"
      error_message += "Время: #{Time.current.strftime('%d.%m.%Y %H:%M:%S')}\n"
      error_message += "Ошибка: #{e.message}\n"
      error_message += "Источник: NBP API"
      
      TelegramService.send_message(error_message, parse_mode: 'HTML')
      
      Rails.logger.error "FetchCurrencyRatesJob: Failed to fetch currency rates: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      
      # Пробрасываем ошибку для логирования в Sidekiq
      raise
    end
  end
  
  private
  
  def cache_currency_rates(rates)
    # Сохраняем курсы в Redis для быстрого доступа
    if defined?(Redis)
      redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0')
      redis.setex('currency_rates', 86400, rates.to_json) # 24 часа
      Rails.logger.info "FetchCurrencyRatesJob: Cached currency rates in Redis"
    end
  rescue => e
    Rails.logger.warn "FetchCurrencyRatesJob: Failed to cache currency rates: #{e.message}"
    # Не критично, продолжаем работу
  end
end

