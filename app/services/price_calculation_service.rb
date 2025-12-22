# Сервис для расчета итоговой цены товара
class PriceCalculationService
  # Получить маржу из настроек
  def self.margin_multiplier
    CalculatorSetting.get('margin_multiplier') || 1.1
  end
  
  # Расчет итоговой цены товара с учетом доставки и таможенной пошлины
  # @param product_price_zl [Float] Цена товара в злотых
  # @param weight_kg [Float] Вес товара в килограммах
  # @param use_gls_pickup [Boolean] Использовать пункт отбора GLS
  # @param date [Date, nil] Дата для курсов валют (по умолчанию сегодня)
  # @return [Hash] Детальный расчет цены
  def self.calculate(product_price_zl, weight_kg, use_gls_pickup: false, date: nil)
    date ||= Date.today
    
    # Получаем курсы валют (с учетом маржи 10%)
    pln_rate = ExchangeRate.fetch_or_create('PLN', date)&.rate_per_unit
    eur_rate = ExchangeRate.fetch_or_create('EUR', date)&.rate_per_unit
    
    return { error: 'Не удалось получить курсы валют' } unless pln_rate && eur_rate
    
    # Применяем маржу к курсам (курс * маржа)
    margin = margin_multiplier
    pln_rate_with_margin = pln_rate * margin
    eur_rate_with_margin = eur_rate * margin
    
    # 1. Расчет доставки по Польше (в злотых)
    poland_delivery_zl = PolandDeliveryService.calculate(weight_kg, use_gls_pickup: use_gls_pickup)
    
    # 2. Конвертация доставки по Польше в BYN (с учетом маржи)
    poland_delivery_byn = (poland_delivery_zl * pln_rate_with_margin).round(2)
    
    # 3. Расчет доставки по Беларуси (в евро)
    belarus_delivery_eur = BelarusDeliveryService.calculate(weight_kg)
    
    # 4. Конвертация доставки по Беларуси в BYN (с учетом маржи)
    belarus_delivery_byn = (belarus_delivery_eur * eur_rate_with_margin).round(2)
    
    # 5. Расчет цены товара с учетом маржи и курса (цена * маржа * курс * маржа)
    product_price_byn = (product_price_zl * margin * pln_rate_with_margin).round(2)
    
    # 6. Расчет таможенной пошлины
    # Сначала конвертируем цену товара в евро для расчета пошлины
    product_price_eur = (product_price_zl * pln_rate / eur_rate).round(2)
    customs = CustomsDutyService.calculate(product_price_eur, weight_kg, eur_rate)
    
    # 7. Итоговая цена
    total_price_byn = (product_price_byn + poland_delivery_byn + belarus_delivery_byn + customs[:total_byn]).round(2)
    
    {
      product_price_zl: product_price_zl.round(2),
      product_price_byn: product_price_byn,
      weight_kg: weight_kg.round(2),
      
      # Доставка
      poland_delivery_zl: poland_delivery_zl.round(2),
      poland_delivery_byn: poland_delivery_byn,
      belarus_delivery_eur: belarus_delivery_eur.round(2),
      belarus_delivery_byn: belarus_delivery_byn,
      
      # Курсы валют
      pln_rate: pln_rate.round(4),
      eur_rate: eur_rate.round(4),
      pln_rate_with_margin: pln_rate_with_margin.round(4),
      eur_rate_with_margin: eur_rate_with_margin.round(4),
      
      # Таможенная пошлина
      customs_duty_eur: customs[:duty_eur],
      customs_duty_byn: customs[:duty_byn],
      customs_fee_byn: customs[:fee_byn],
      customs_total_byn: customs[:total_byn],
      customs_details: customs[:details],
      
      # Итого
      total_price_byn: total_price_byn,
      
      # Детализация
      breakdown: {
        product: product_price_byn,
        poland_delivery: poland_delivery_byn,
        belarus_delivery: belarus_delivery_byn,
        customs: customs[:total_byn],
        total: total_price_byn
      }
    }
  end
end

