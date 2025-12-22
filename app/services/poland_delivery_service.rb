# Сервис для расчета доставки по Польше
class PolandDeliveryService
  # Получить тарифы доставки из настроек
  def self.delivery_rates
    rates = CalculatorSetting.get('poland_delivery_rates') || {
      '0-1' => 0.0,
      '1-50' => 79.0,
      '50-100' => 119.0,
      '100-200' => 169.0,
      '200-400' => 329.0,
      '400-600' => 499.0,
      '600-1000' => 599.0
    }
    
    # Преобразуем в массив для удобства
    rates.map { |range, price| [parse_range(range), price] }.sort_by { |range| range[0] }
  end
  
  # Получить бесплатный вес для GLS
  def self.gls_free_weight
    CalculatorSetting.get('gls_pickup_free_weight') || 30.0
  end
  
  # Парсинг диапазона веса
  def self.parse_range(range_str)
    parts = range_str.split('-').map(&:to_f)
    [parts[0], parts[1] || Float::INFINITY]
  end
  
  # Расчет стоимости доставки по Польше в злотых
  # @param weight_kg [Float] Вес в килограммах
  # @param use_gls_pickup [Boolean] Использовать пункт отбора GLS
  # @return [Float] Стоимость доставки в злотых
  def self.calculate(weight_kg, use_gls_pickup: false)
    weight = weight_kg.to_f
    
    # Если используется GLS пункт отбора и вес до лимита - бесплатно
    if use_gls_pickup && weight <= gls_free_weight
      return 0.0
    end
    
    # Получаем тарифы из настроек
    rates = delivery_rates
    
    # Находим подходящий тариф
    rates.each do |(min_weight, max_weight), price|
      if weight > min_weight && weight <= max_weight
        return price
      end
    end
    
    # Если вес больше максимального диапазона, используем последний тариф + доплата
    last_range = rates.last
    last_price = last_range[1]
    last_max = last_range[0][1]
    
    if last_max != Float::INFINITY && weight > last_max
      # Доплата за каждые 100 кг сверх лимита
      extra_weight = weight - last_max
      extra_charge = (extra_weight / 100.0).ceil * 50.0
      return last_price + extra_charge
    end
    
    # Fallback на последний тариф
    last_price
  end
end

