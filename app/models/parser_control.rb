# Виртуальная модель для админ-панели управления парсером
class ParserControl
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string, default: 'show'

  def self.all
    [new(id: 'show')]
  end

  def self.find(id)
    new(id: id)
  end

  def persisted?
    true
  end

  def to_param
    id
  end
end
