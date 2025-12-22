require 'rails_helper'

RSpec.describe CustomsDutyService do
  let(:eur_rate) { 3.5 }
  
  before do
    CalculatorSetting.initialize_defaults
  end
  
  describe '.calculate' do
    context 'Сценарий 1: Превышение только стоимостного лимита' do
      let(:cost_eur) { 350.0 }
      let(:weight_kg) { 15.0 }
      
      it 'рассчитывает пошлину по стоимости' do
        result = described_class.calculate(cost_eur, weight_kg, eur_rate)
        
        expect(result[:duty_eur]).to be > 0
        expect(result[:duty_byn]).to be > 0
        expect(result[:details][:scenario]).to eq(1)
        expect(result[:details][:cost_limit_exceeded]).to be true
        expect(result[:details][:weight_limit_exceeded]).to be false
      end
      
      it 'правильно рассчитывает превышение стоимости' do
        result = described_class.calculate(cost_eur, weight_kg, eur_rate)
        
        expected_duty_eur = (350.0 - 200.0) * 0.15
        expect(result[:duty_eur]).to be_within(0.01).of(expected_duty_eur)
      end
    end
    
    context 'Сценарий 2: Превышение только весового лимита' do
      let(:cost_eur) { 150.0 }
      let(:weight_kg) { 41.0 }
      
      it 'рассчитывает пошлину по весу' do
        result = described_class.calculate(cost_eur, weight_kg, eur_rate)
        
        expect(result[:duty_eur]).to be > 0
        expect(result[:duty_byn]).to be > 0
        expect(result[:details][:scenario]).to eq(2)
        expect(result[:details][:cost_limit_exceeded]).to be false
        expect(result[:details][:weight_limit_exceeded]).to be true
      end
      
      it 'правильно рассчитывает превышение веса' do
        result = described_class.calculate(cost_eur, weight_kg, eur_rate)
        
        expected_duty_eur = (41.0 - 31.0) * 2.0
        expect(result[:duty_eur]).to be_within(0.01).of(expected_duty_eur)
      end
    end
    
    context 'Сценарий 3: Двойное превышение' do
      let(:cost_eur) { 450.0 }
      let(:weight_kg) { 51.0 }
      
      it 'выбирает максимальную пошлину' do
        result = described_class.calculate(cost_eur, weight_kg, eur_rate)
        
        expect(result[:duty_eur]).to be > 0
        expect(result[:details][:scenario]).to eq(3)
        expect(result[:details][:cost_limit_exceeded]).to be true
        expect(result[:details][:weight_limit_exceeded]).to be true
      end
      
      it 'правильно выбирает максимальную пошлину' do
        result = described_class.calculate(cost_eur, weight_kg, eur_rate)
        
        duty_by_cost = (450.0 - 200.0) * 0.15 # 37.5 EUR
        duty_by_weight = (51.0 - 31.0) * 2.0 # 40 EUR
        
        expect(result[:duty_eur]).to eq([duty_by_cost, duty_by_weight].max)
        expect(result[:details][:max_duty_used]).to eq('weight')
      end
    end
    
    context 'Сценарий 4: В пределах нормы' do
      let(:cost_eur) { 190.0 }
      let(:weight_kg) { 25.0 }
      
      it 'не начисляет пошлину' do
        result = described_class.calculate(cost_eur, weight_kg, eur_rate)
        
        expect(result[:duty_eur]).to eq(0.0)
        expect(result[:duty_byn]).to eq(0.0)
        expect(result[:fee_byn]).to eq(0.0)
        expect(result[:total_byn]).to eq(0.0)
        expect(result[:details][:scenario]).to eq(4)
      end
    end
    
    context 'Таможенный сбор' do
      it 'взимается при превышении лимитов' do
        result = described_class.calculate(250.0, 35.0, eur_rate)
        
        expect(result[:fee_byn]).to eq(10.0)
      end
      
      it 'не взимается в пределах нормы' do
        result = described_class.calculate(190.0, 25.0, eur_rate)
        
        expect(result[:fee_byn]).to eq(0.0)
      end
    end
    
    context 'Округление' do
      it 'округляет все значения до 2 знаков после запятой' do
        result = described_class.calculate(350.0, 15.0, eur_rate)
        
        expect(result[:duty_eur].to_s.split('.').last.length).to be <= 2
        expect(result[:duty_byn].to_s.split('.').last.length).to be <= 2
        expect(result[:total_byn].to_s.split('.').last.length).to be <= 2
      end
    end
  end
  
  describe 'методы получения настроек' do
    it '.free_cost_limit возвращает значение из настроек' do
      expect(described_class.free_cost_limit).to eq(200.0)
    end
    
    it '.free_weight_limit возвращает значение из настроек' do
      expect(described_class.free_weight_limit).to eq(31.0)
    end
    
    it '.cost_duty_rate возвращает значение из настроек' do
      expect(described_class.cost_duty_rate).to eq(0.15)
    end
    
    it '.weight_duty_rate возвращает значение из настроек' do
      expect(described_class.weight_duty_rate).to eq(2.0)
    end
    
    it '.customs_fee возвращает значение из настроек' do
      expect(described_class.customs_fee).to eq(10.0)
    end
  end
end

