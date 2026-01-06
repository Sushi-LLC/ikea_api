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
  # Фильтрует только нужные валюты: PLN, USD, EUR
  def self.format_rates_for_telegram(rates)
    return "Курсы валют не найдены" if rates.empty?
    
    # Список нужных валют
    target_codes = %w[USD EUR]
    
    # Фильтруем только нужные валюты
    filtered_rates = rates[:rates].select { |rate| target_codes.include?(rate[:code]) }
    
    # Добавляем PLN как базовую валюту (1.0 PLN)
    filtered_rates << {
      currency: 'złoty polski',
      code: 'PLN',
      mid: 1.0
    }
    
    # Сортируем: PLN, USD, EUR
    sorted_rates = filtered_rates.sort_by do |rate|
      case rate[:code]
      when 'PLN' then 0
      when 'USD' then 1
      when 'EUR' then 2
      else 3
      end
    end
    
    message = "💱 <b>Актуальные курсы валют (NBP)</b>\n\n"
    message += "Дата: #{rates[:effective_date]}\n"
    
    if sorted_rates.any?
      sorted_rates.each do |rate|
        emoji = case rate[:code]
                when 'PLN' then '🇵🇱'
                when 'USD' then '🇺🇸'
                when 'EUR' then '🇪🇺'
                else '💱'
                end
        
        message += "#{emoji} <b>#{rate[:currency]}</b>\n"
        message += "   Код: #{rate[:code]}\n"
        if rate[:code] == 'PLN'
          message += "   Курс: 1.0 PLN (базовая валюта)\n\n"
        else
          message += "   Курс: #{rate[:mid]} PLN\n\n"
        end
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

