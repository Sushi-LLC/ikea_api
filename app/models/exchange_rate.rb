class ExchangeRate < ApplicationRecord
  validates :date, presence: true
  validates :currency_code, presence: true
  validates :rate, presence: true, numericality: { greater_than: 0 }
  validates :scale, presence: true, numericality: { greater_than: 0 }
  validates :currency_code, uniqueness: { scope: :date }
  
  # Получить курс за 1 единицу валюты
  def rate_per_unit
    rate / scale.to_f
  end
  
  # Получить актуальный курс валюты
  # @param currency_code [String] Код валюты
  # @param date [Date, nil] Дата (по умолчанию сегодня)
  # @return [ExchangeRate, nil]
  def self.current(currency_code, date = nil)
    date ||= Date.today
    where(currency_code: currency_code.upcase, date: date).first
  end
  
  # Получить или создать курс из API НБ РБ
  # @param currency_code [String] Код валюты
  # @param date [Date, nil] Дата
  # @return [ExchangeRate, nil]
  def self.fetch_or_create(currency_code, date = nil)
    date ||= Date.today
    
    # Проверяем, есть ли уже курс в БД
    rate = current(currency_code, date)
    return rate if rate
    
    # Получаем курс из API
    rate_data = NbrbApiService.get_rate(currency_code, date)
    return nil unless rate_data
    
    # Сохраняем в БД
    create!(
      date: rate_data[:date],
      currency_code: rate_data[:currency_code],
      rate: rate_data[:rate],
      official_rate: rate_data[:rate],
      scale: rate_data[:scale]
    )
  end
end

