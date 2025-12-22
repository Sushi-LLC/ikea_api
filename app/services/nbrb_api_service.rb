# Сервис для работы с API Национального банка Республики Беларусь
class NbrbApiService
  BASE_URL = 'https://www.nbrb.by/api/exrates/rates'.freeze

  # Получить курс валюты по коду (USD, EUR, PLN и т.д.)
  # @param currency_code [String] Код валюты (USD, EUR, PLN)
  # @param date [Date, nil] Дата курса (по умолчанию сегодня)
  # @return [Hash, nil] Информация о курсе или nil при ошибке
  def self.get_rate(currency_code, date = nil)
    date ||= Date.today
    
    # Коды валют в API НБ РБ
    currency_ids = {
      'USD' => 145,
      'EUR' => 292,
      'PLN' => 293,
      'RUB' => 298
    }
    
    currency_id = currency_ids[currency_code.upcase]
    return nil unless currency_id
    
    url = "#{BASE_URL}/#{currency_id}?ondate=#{date.strftime('%Y-%m-%d')}"
    
    begin
      response = HTTParty.get(url, timeout: 10)
      
      if response.success?
        data = JSON.parse(response.body)
        {
          currency_code: currency_code.upcase,
          date: Date.parse(data['Date']),
          rate: data['Cur_OfficialRate'].to_f,
          scale: data['Cur_Scale'].to_i
        }
      else
        Rails.logger.error "NBRB API error: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "NBRB API exception: #{e.class} - #{e.message}"
      nil
    end
  end
  
  # Получить курс валюты с учетом масштаба (например, для PLN курс на 10 единиц)
  # @param currency_code [String] Код валюты
  # @param date [Date, nil] Дата курса
  # @return [Float, nil] Курс за 1 единицу валюты или nil
  def self.get_rate_per_unit(currency_code, date = nil)
    rate_data = get_rate(currency_code, date)
    return nil unless rate_data
    
    # Курс уже в расчете на scale единиц, делим на scale
    rate_data[:rate] / rate_data[:scale].to_f
  end
  
  # Получить курсы нескольких валют одновременно
  # @param currency_codes [Array<String>] Массив кодов валют
  # @param date [Date, nil] Дата курса
  # @return [Hash] Хеш с курсами { 'USD' => 3.5, 'EUR' => 3.8, ... }
  def self.get_rates(currency_codes, date = nil)
    result = {}
    currency_codes.each do |code|
      rate = get_rate_per_unit(code, date)
      result[code.upcase] = rate if rate
    end
    result
  end
end

