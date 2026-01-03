# Сервис для получения курсов валют из API Национального банка Польши (NBP)
require 'net/http'
require 'json'
require 'uri'

class CurrencyRateService
  NBP_API_BASE_URL = 'http://api.nbp.pl/api/exchangerates/tables/A/'
  
  # Получить актуальные курсы валют
  def self.fetch_rates
    uri = URI(NBP_API_BASE_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 10
    http.open_timeout = 10
    
    request = Net::HTTP::Get.new(uri.path)
    request['Accept'] = 'application/json'
    
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      parse_rates(data)
    else
      raise StandardError, "NBP API error: #{response.code} #{response.message}"
    end
  rescue JSON::ParserError => e
    raise StandardError, "Failed to parse NBP API response: #{e.message}"
  rescue Net::TimeoutError => e
    raise StandardError, "NBP API timeout: #{e.message}"
  rescue => e
    raise StandardError, "Failed to fetch currency rates: #{e.message}"
  end
  
  # Форматировать курсы для Telegram сообщения
  def self.format_rates_for_telegram(rates)
    return "Курсы валют не найдены" if rates.empty?
    
    message = "💱 <b>Актуальные курсы валют (NBP)</b>\n\n"
    message += "Дата: #{rates[:effective_date]}\n"
    message += "Таблица: #{rates[:table]}\n\n"
    
    if rates[:rates].any?
      rates[:rates].each do |rate|
        message += "🇪🇺 <b>#{rate[:currency]}</b>\n"
        message += "   Код: #{rate[:code]}\n"
        message += "   Курс: #{rate[:mid]} PLN\n\n"
      end
    else
      message += "Курсы валют не найдены"
    end
    
    message
  end
  
  private
  
  def self.parse_rates(data)
    return { rates: [], effective_date: nil, table: nil } if data.empty?
    
    # NBP API возвращает массив таблиц, берем первую
    table_data = data.first
    
    rates = (table_data['rates'] || []).map do |rate|
      {
        currency: rate['currency'],
        code: rate['code'],
        mid: rate['mid']
      }
    end
    
    {
      rates: rates,
      effective_date: table_data['effectiveDate'],
      table: table_data['table'],
      no: table_data['no']
    }
  end
end

