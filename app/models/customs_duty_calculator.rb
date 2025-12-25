# Виртуальная модель для калькулятора таможенной пошлины
class CustomsDutyCalculator
  include ActiveModel::Model
  
  attr_accessor :id
  
  def self.find(id)
    new(id: id)
  end
  
  def persisted?
    true
  end
  
  def to_param
    id.to_s
  end
  
  def self.all
    [new(id: 'show')]
  end
end

