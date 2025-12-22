require 'rails_helper'

RSpec.describe PolandDeliveryService do
  before do
    CalculatorSetting.initialize_defaults
  end
  
  describe '.calculate' do
    context 'с GLS пунктом отбора' do
      it 'бесплатно для веса до 30 кг' do
        expect(described_class.calculate(25.0, use_gls_pickup: true)).to eq(0.0)
        expect(described_class.calculate(30.0, use_gls_pickup: true)).to eq(0.0)
      end
      
      it 'платно для веса более 30 кг' do
        result = described_class.calculate(35.0, use_gls_pickup: true)
        expect(result).to be > 0
      end
    end
    
    context 'без GLS пункта отбора' do
      it 'возвращает 0 для веса до 1 кг' do
        expect(described_class.calculate(0.5, use_gls_pickup: false)).to eq(0.0)
      end
      
      it 'возвращает 79 zl для веса 1-50 кг' do
        expect(described_class.calculate(25.0, use_gls_pickup: false)).to eq(79.0)
        expect(described_class.calculate(50.0, use_gls_pickup: false)).to eq(79.0)
      end
      
      it 'возвращает 119 zl для веса 50-100 кг' do
        expect(described_class.calculate(75.0, use_gls_pickup: false)).to eq(119.0)
        expect(described_class.calculate(100.0, use_gls_pickup: false)).to eq(119.0)
      end
      
      it 'возвращает 169 zl для веса 100-200 кг' do
        expect(described_class.calculate(150.0, use_gls_pickup: false)).to eq(169.0)
      end
      
      it 'возвращает 329 zl для веса 200-400 кг' do
        expect(described_class.calculate(300.0, use_gls_pickup: false)).to eq(329.0)
      end
      
      it 'возвращает 499 zl для веса 400-600 кг' do
        expect(described_class.calculate(500.0, use_gls_pickup: false)).to eq(499.0)
      end
      
      it 'возвращает 599 zl для веса 600-1000 кг' do
        expect(described_class.calculate(800.0, use_gls_pickup: false)).to eq(599.0)
      end
      
      it 'добавляет доплату для веса более 1000 кг' do
        result = described_class.calculate(1200.0, use_gls_pickup: false)
        expect(result).to be > 599.0
      end
    end
  end
  
  describe '.delivery_rates' do
    it 'возвращает тарифы из настроек' do
      rates = described_class.delivery_rates
      expect(rates).to be_an(Array)
      expect(rates.length).to be > 0
    end
  end
  
  describe '.gls_free_weight' do
    it 'возвращает значение из настроек' do
      expect(described_class.gls_free_weight).to eq(30.0)
    end
  end
end

