# Сервис для расчета доставки по Беларуси
class BelarusDeliveryService
  # Получить тарифы доставки из настроек
  def self.delivery_rates
    rates = CalculatorSetting.get('belarus_delivery_rates') || {
      '0-20' => 3.0,
      '20-30' => 2.0,
      '30-40' => 1.5,
      '40-1000' => 1.0
    }
    
    # Преобразуем в массив для удобства
    rates.map { |range, price_per_kg| [parse_range(range), price_per_kg] }.sort_by { |range| range[0] }
  end
  
  # Парсинг диапазона веса
  def self.parse_range(range_str)
    parts = range_str.split('-').map(&:to_f)
    [parts[0], parts[1] || Float::INFINITY]
  end
  
  # Расчет стоимости доставки по Беларуси в евро
  # @param weight_kg [Float] Вес в килограммах
  # @return [Float] Стоимость доставки в евро
  def self.calculate(weight_kg)
    weight = weight_kg.to_f
    
    # Получаем тарифы из настроек
    rates = delivery_rates
    
    # Находим подходящий тариф (цена за килограмм)
    price_per_kg = nil
    rates.each do |(min_weight, max_weight), rate|
      if weight > min_weight && weight <= max_weight
        price_per_kg = rate
        break
      end
    end
    
    # Если не нашли, используем последний тариф
    price_per_kg ||= rates.last[1]
    
    # Стоимость = вес * цена за килограмм
    (weight * price_per_kg).round(2)
  end
end

