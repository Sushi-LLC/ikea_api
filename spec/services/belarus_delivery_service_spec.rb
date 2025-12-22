require 'rails_helper'

RSpec.describe BelarusDeliveryService do
  before do
    CalculatorSetting.initialize_defaults
  end
  
  describe '.calculate' do
    it 'возвращает 3 EUR за кг для веса 0-20 кг' do
      expect(described_class.calculate(10.0)).to eq(30.0) # 10 * 3
      expect(described_class.calculate(20.0)).to eq(60.0) # 20 * 3
    end
    
    it 'возвращает 2 EUR за кг для веса 20-30 кг' do
      expect(described_class.calculate(25.0)).to eq(50.0) # 25 * 2
      expect(described_class.calculate(30.0)).to eq(60.0) # 30 * 2
    end
    
    it 'возвращает 1.5 EUR за кг для веса 30-40 кг' do
      expect(described_class.calculate(35.0)).to eq(52.5) # 35 * 1.5
      expect(described_class.calculate(40.0)).to eq(60.0) # 40 * 1.5
    end
    
    it 'возвращает 1 EUR за кг для веса 40-1000 кг' do
      expect(described_class.calculate(50.0)).to eq(50.0) # 50 * 1
      expect(described_class.calculate(100.0)).to eq(100.0) # 100 * 1
      expect(described_class.calculate(1000.0)).to eq(1000.0) # 1000 * 1
    end
    
    it 'возвращает 1 EUR за кг для веса более 1000 кг' do
      expect(described_class.calculate(1500.0)).to eq(1500.0) # 1500 * 1
    end
    
    it 'округляет результат до 2 знаков после запятой' do
      result = described_class.calculate(35.0)
      expect(result.to_s.split('.').last.length).to be <= 2
    end
  end
  
  describe '.delivery_rates' do
    it 'возвращает тарифы из настроек' do
      rates = described_class.delivery_rates
      expect(rates).to be_an(Array)
      expect(rates.length).to be > 0
    end
  end
end

