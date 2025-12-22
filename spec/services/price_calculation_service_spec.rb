require 'rails_helper'

RSpec.describe PriceCalculationService do
  let(:date) { Date.today }
  
  before do
    # Создаем настройки по умолчанию
    CalculatorSetting.initialize_defaults
    
    # Создаем тестовые курсы валют
    ExchangeRate.create!(
      date: date,
      currency_code: 'PLN',
      rate: 8.5,
      official_rate: 8.5,
      scale: 1
    )
    
    ExchangeRate.create!(
      date: date,
      currency_code: 'EUR',
      rate: 3.5,
      official_rate: 3.5,
      scale: 1
    )
  end
  
  describe '.calculate' do
    context 'с базовыми параметрами' do
      let(:product_price_zl) { 100.0 }
      let(:weight_kg) { 25.0 }
      
      it 'возвращает корректный расчет' do
        result = described_class.calculate(product_price_zl, weight_kg, use_gls_pickup: false, date: date)
        
        expect(result).to be_a(Hash)
        expect(result[:product_price_zl]).to eq(100.0)
        expect(result[:weight_kg]).to eq(25.0)
        expect(result[:total_price_byn]).to be > 0
        expect(result[:breakdown]).to be_a(Hash)
      end
      
      it 'включает все компоненты в breakdown' do
        result = described_class.calculate(product_price_zl, weight_kg, use_gls_pickup: false, date: date)
        
        expect(result[:breakdown]).to include(:product, :poland_delivery, :belarus_delivery, :customs, :total)
      end
    end
    
    context 'с GLS пунктом отбора' do
      let(:product_price_zl) { 50.0 }
      let(:weight_kg) { 25.0 }
      
      it 'доставка по Польше бесплатна для веса до 30 кг' do
        result = described_class.calculate(product_price_zl, weight_kg, use_gls_pickup: true, date: date)
        
        expect(result[:poland_delivery_zl]).to eq(0.0)
      end
    end
    
    context 'с превышением таможенных лимитов' do
      let(:product_price_zl) { 500.0 } # ~58.8 EUR при курсе 8.5
      let(:weight_kg) { 50.0 }
      
      it 'включает таможенную пошлину' do
        result = described_class.calculate(product_price_zl, weight_kg, use_gls_pickup: false, date: date)
        
        expect(result[:customs_total_byn]).to be > 0
      end
    end
    
    context 'без курсов валют' do
      before do
        ExchangeRate.destroy_all
      end
      
      it 'возвращает ошибку' do
        result = described_class.calculate(100.0, 25.0, use_gls_pickup: false, date: date)
        
        expect(result[:error]).to be_present
      end
    end
  end
  
  describe '.margin_multiplier' do
    it 'возвращает значение из настроек' do
      expect(described_class.margin_multiplier).to eq(1.1)
    end
    
    it 'использует значение по умолчанию если настройка отсутствует' do
      CalculatorSetting.find_by(key: 'margin_multiplier')&.destroy
      
      expect(described_class.margin_multiplier).to eq(1.1)
    end
  end
end

