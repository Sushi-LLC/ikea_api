class SmsSenderService
  def self.send(phone, code)
    # Здесь должна быть интеграция с реальным SMS-шлюзом
    # Пока просто логируем код для отладки
    Rails.logger.info "\n[SMS MOCK] Sending code #{code} to #{phone}\n"
    puts "\n[SMS MOCK] Sending code #{code} to #{phone}\n" # дублируем в stdout для наглядности
    true
  end
end
