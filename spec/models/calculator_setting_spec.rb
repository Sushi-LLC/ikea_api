require 'rails_helper'

RSpec.describe CalculatorSetting, type: :model do
  describe 'валидации' do
    it 'требует наличие key' do
      setting = CalculatorSetting.new(value: '1.1', setting_type: 'decimal')
      expect(setting).not_to be_valid
      expect(setting.errors[:key]).to be_present
    end
    
    it 'требует наличие value' do
      setting = CalculatorSetting.new(key: 'test', setting_type: 'decimal')
      expect(setting).not_to be_valid
      expect(setting.errors[:value]).to be_present
    end
    
    it 'требует наличие setting_type' do
      setting = CalculatorSetting.new(key: 'test', value: '1.1')
      expect(setting).not_to be_valid
      expect(setting.errors[:setting_type]).to be_present
    end
    
    it 'требует уникальность key' do
      CalculatorSetting.create!(key: 'test', value: '1.1', setting_type: 'decimal')
      duplicate = CalculatorSetting.new(key: 'test', value: '2.2', setting_type: 'decimal')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to be_present
    end
    
    it 'валидирует setting_type' do
      setting = CalculatorSetting.new(key: 'test', value: '1.1', setting_type: 'invalid')
      expect(setting).not_to be_valid
      expect(setting.errors[:setting_type]).to be_present
    end
  end
  
  describe '.get' do
    before do
      CalculatorSetting.create!(key: 'test_decimal', value: '1.5', setting_type: 'decimal')
      CalculatorSetting.create!(key: 'test_integer', value: '10', setting_type: 'integer')
      CalculatorSetting.create!(key: 'test_json', value: '{"a": 1}', setting_type: 'json')
    end
    
    it 'возвращает decimal значение' do
      expect(CalculatorSetting.get('test_decimal')).to eq(1.5)
    end
    
    it 'возвращает integer значение' do
      expect(CalculatorSetting.get('test_integer')).to eq(10)
    end
    
    it 'возвращает json значение' do
      expect(CalculatorSetting.get('test_json')).to eq({ 'a' => 1 })
    end
    
    it 'возвращает nil для несуществующего ключа' do
      expect(CalculatorSetting.get('nonexistent')).to be_nil
    end
  end
  
  describe '.set' do
    it 'создает новую настройку' do
      CalculatorSetting.set('new_setting', 2.5, setting_type: 'decimal')
      
      setting = CalculatorSetting.find_by(key: 'new_setting')
      expect(setting).to be_present
      expect(setting.decimal_value).to eq(2.5)
    end
    
    it 'обновляет существующую настройку' do
      CalculatorSetting.set('existing', 1.0, setting_type: 'decimal')
      CalculatorSetting.set('existing', 2.0, setting_type: 'decimal')
      
      expect(CalculatorSetting.get('existing')).to eq(2.0)
    end
  end
  
  describe '.initialize_defaults' do
    it 'создает все настройки по умолчанию' do
      CalculatorSetting.initialize_defaults
      
      expect(CalculatorSetting.get('margin_multiplier')).to eq(1.1)
      expect(CalculatorSetting.get('poland_delivery_rates')).to be_a(Hash)
      expect(CalculatorSetting.get('belarus_delivery_rates')).to be_a(Hash)
      expect(CalculatorSetting.get('customs_free_cost_limit')).to eq(200.0)
      expect(CalculatorSetting.get('customs_free_weight_limit')).to eq(31.0)
    end
  end
  
  describe '#decimal_value' do
    it 'возвращает значение как float для decimal типа' do
      setting = CalculatorSetting.new(key: 'test', value: '1.5', setting_type: 'decimal')
      expect(setting.decimal_value).to eq(1.5)
    end
    
    it 'возвращает nil для не-decimal типа' do
      setting = CalculatorSetting.new(key: 'test', value: '1', setting_type: 'integer')
      expect(setting.decimal_value).to be_nil
    end
  end
  
  describe '#json_value' do
    it 'возвращает распарсенный JSON' do
      setting = CalculatorSetting.new(key: 'test', value: '{"a": 1}', setting_type: 'json')
      expect(setting.json_value).to eq({ 'a' => 1 })
    end
    
    it 'возвращает nil для невалидного JSON' do
      setting = CalculatorSetting.new(key: 'test', value: 'invalid json', setting_type: 'json')
      expect(setting.json_value).to be_nil
    end
  end
end

