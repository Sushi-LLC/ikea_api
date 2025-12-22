class CalculatorSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true
  validates :setting_type, presence: true, inclusion: { in: %w[decimal integer json] }
  
  # Получить значение как decimal
  def decimal_value
    return nil unless setting_type == 'decimal'
    value.to_f
  end
  
  # Получить значение как integer
  def integer_value
    return nil unless setting_type == 'integer'
    value.to_i
  end
  
  # Получить значение как JSON
  def json_value
    return nil unless setting_type == 'json'
    JSON.parse(value)
  rescue JSON::ParserError
    nil
  end
  
  # Установить значение
  def set_value(val)
    case setting_type
    when 'decimal', 'integer'
      self.value = val.to_s
    when 'json'
      self.value = val.is_a?(String) ? val : val.to_json
    end
  end
  
  # Получить настройку по ключу
  def self.get(key)
    setting = find_by(key: key)
    return nil unless setting
    
    case setting.setting_type
    when 'decimal'
      setting.decimal_value
    when 'integer'
      setting.integer_value
    when 'json'
      setting.json_value
    end
  end
  
  # Установить настройку
  def self.set(key, value, setting_type: 'decimal', description: nil)
    setting = find_or_initialize_by(key: key)
    setting.setting_type = setting_type
    setting.description = description if description
    setting.set_value(value)
    setting.save!
    setting
  end
  
  # Инициализация дефолтных настроек
  def self.initialize_defaults
    # Маржа
    set('margin_multiplier', 1.1, setting_type: 'decimal', description: 'Маржа (10% = 1.1)')
    
    # Тарифы доставки по Польше (вес в кг => цена в zl)
    poland_rates = {
      '0-1' => 0.0,
      '1-50' => 79.0,
      '50-100' => 119.0,
      '100-200' => 169.0,
      '200-400' => 329.0,
      '400-600' => 499.0,
      '600-1000' => 599.0
    }
    set('poland_delivery_rates', poland_rates, setting_type: 'json', 
        description: 'Тарифы доставки по Польше (вес в кг => цена в zl)')
    
    # Тарифы доставки по Беларуси (вес в кг => цена в EUR за кг)
    belarus_rates = {
      '0-20' => 3.0,
      '20-30' => 2.0,
      '30-40' => 1.5,
      '40-1000' => 1.0
    }
    set('belarus_delivery_rates', belarus_rates, setting_type: 'json',
        description: 'Тарифы доставки по Беларуси (вес в кг => цена в EUR за кг)')
    
    # Таможенные лимиты
    set('customs_free_cost_limit', 200.0, setting_type: 'decimal',
        description: 'Норма беспошлинного ввоза по стоимости (EUR)')
    set('customs_free_weight_limit', 31.0, setting_type: 'decimal',
        description: 'Норма беспошлинного ввоза по весу (кг)')
    
    # Таможенные ставки
    set('customs_cost_duty_rate', 0.15, setting_type: 'decimal',
        description: 'Ставка пошлины при превышении стоимости (15% = 0.15)')
    set('customs_weight_duty_rate', 2.0, setting_type: 'decimal',
        description: 'Ставка пошлины при превышении веса (EUR за кг)')
    set('customs_fee', 10.0, setting_type: 'decimal',
        description: 'Таможенный сбор (BYN)')
    
    # GLS пункт отбора
    set('gls_pickup_free_weight', 30.0, setting_type: 'decimal',
        description: 'Бесплатный вес для GLS пункта отбора (кг)')
  end
end

