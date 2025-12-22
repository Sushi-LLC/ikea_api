# Сервис для расчета таможенной пошлины
class CustomsDutyService
  # Получить лимиты и ставки из настроек
  def self.free_cost_limit
    CalculatorSetting.get('customs_free_cost_limit') || 200.0
  end
  
  def self.free_weight_limit
    CalculatorSetting.get('customs_free_weight_limit') || 31.0
  end
  
  def self.cost_duty_rate
    CalculatorSetting.get('customs_cost_duty_rate') || 0.15
  end
  
  def self.weight_duty_rate
    CalculatorSetting.get('customs_weight_duty_rate') || 2.0
  end
  
  def self.customs_fee
    CalculatorSetting.get('customs_fee') || 10.0
  end
  
  # Расчет таможенной пошлины
  # @param cost_eur [Float] Стоимость товара в евро
  # @param weight_kg [Float] Вес товара в килограммах
  # @param eur_rate [Float] Курс евро к BYN (от НБ РБ)
  # @return [Hash] Хеш с деталями расчета: { duty: Float, fee: Float, total: Float, details: Hash }
  def self.calculate(cost_eur, weight_kg, eur_rate)
    cost = cost_eur.to_f
    weight = weight_kg.to_f
    rate = eur_rate.to_f
    
    # Получаем лимиты из настроек
    cost_limit = free_cost_limit
    weight_limit = free_weight_limit
    
    # Проверяем превышение лимитов
    cost_exceeded = cost > cost_limit
    weight_exceeded = weight > weight_limit
    
    duty_eur = 0.0
    details = {
      cost_limit_exceeded: cost_exceeded,
      weight_limit_exceeded: weight_exceeded,
      cost_excess: cost_exceeded ? (cost - cost_limit) : 0.0,
      weight_excess: weight_exceeded ? (weight - weight_limit) : 0.0
    }
    
    if !cost_exceeded && !weight_exceeded
      # Сценарий 4: В пределах нормы (без пошлины)
      details[:scenario] = 4
      details[:duty_by_cost_eur] = 0.0
      details[:duty_by_weight_eur] = 0.0
      duty_eur = 0.0
    elsif cost_exceeded && !weight_exceeded
      # Сценарий 1: Превышение только стоимостного лимита
      details[:scenario] = 1
      duty_eur = (cost - cost_limit) * cost_duty_rate
      details[:duty_by_cost_eur] = duty_eur
      details[:duty_by_weight_eur] = 0.0
    elsif !cost_exceeded && weight_exceeded
      # Сценарий 2: Превышение только весового лимита
      details[:scenario] = 2
      duty_eur = (weight - weight_limit) * weight_duty_rate
      details[:duty_by_cost_eur] = 0.0
      details[:duty_by_weight_eur] = duty_eur
    else
      # Сценарий 3: Двойное превышение
      details[:scenario] = 3
      duty_by_cost_eur = (cost - cost_limit) * cost_duty_rate
      duty_by_weight_eur = (weight - weight_limit) * weight_duty_rate
      
      # Выбираем максимальную пошлину
      duty_eur = [duty_by_cost_eur, duty_by_weight_eur].max
      details[:duty_by_cost_eur] = duty_by_cost_eur
      details[:duty_by_weight_eur] = duty_by_weight_eur
      details[:max_duty_used] = duty_by_cost_eur > duty_by_weight_eur ? 'cost' : 'weight'
    end
    
    # Конвертируем пошлину в BYN
    duty_byn = duty_eur * rate
    
    # Таможенный сбор взимается только при превышении лимитов
    fee_byn = (cost_exceeded || weight_exceeded) ? customs_fee : 0.0
    
    total_byn = duty_byn + fee_byn
    
    {
      duty_eur: duty_eur.round(2),
      duty_byn: duty_byn.round(2),
      fee_byn: fee_byn.round(2),
      total_byn: total_byn.round(2),
      details: details
    }
  end
end

