# Сервис для заполнения характеристик продуктов на основе названия
class ProductCharacteristicsFiller
  def self.fill_from_name(product)
    return product unless product.name_ru.present?
    
    name_lower = product.name_ru.downcase
    updates = {}
    
    # Материалы
    if product.materials.blank?
      materials = extract_materials(name_lower)
      updates[:materials] = materials if materials.present?
    end
    
    # Особенности
    if product.features.blank?
      features = extract_features(name_lower, product.name_ru)
      updates[:features] = features if features.present?
    end
    
    # Инструкции по уходу
    if product.care_instructions.blank?
      care = extract_care_instructions(name_lower)
      updates[:care_instructions] = care if care.present?
    end
    
    # Экологическая информация
    if product.environmental_info.blank?
      env = extract_environmental_info(name_lower)
      updates[:environmental_info] = env if env.present?
    end
    
    # Краткое описание
    if product.short_description.blank? && product.name_ru.present?
      updates[:short_description] = product.name_ru.split(' - ').first || product.name_ru
    end
    
    product.update_columns(updates) if updates.any?
    product.reload
    product
  end
  
  private
  
  def self.extract_materials(name_lower)
    materials_map = {
      'пластик' => 'Пластик',
      'plastik' => 'Пластик',
      'стекло' => 'Стекло',
      'szkło' => 'Стекло',
      'металл' => 'Металл',
      'metal' => 'Металл',
      'сталь' => 'Нержавеющая сталь',
      'stal' => 'Нержавеющая сталь',
      'дерево' => 'Дерево',
      'drewno' => 'Дерево',
      'текстиль' => 'Текстиль',
      'tkanina' => 'Текстиль',
      'хлопок' => 'Хлопок',
      'bawełna' => 'Хлопок',
      'полиэстер' => 'Полиэстер',
      'poliester' => 'Полиэстер',
      'led' => 'LED',
      'ceramika' => 'Керамика',
      'керамика' => 'Керамика'
    }
    
    materials_map.each do |keyword, material|
      return material if name_lower.include?(keyword)
    end
    
    nil
  end
  
  def self.extract_features(name_lower, name_ru)
    features_map = {
      ['контейнер', 'pojemnik'] => 'Герметичная крышка, удобное хранение продуктов',
      ['освещение', 'oświetlenie', 'lampa'] => 'Энергосберегающее LED освещение',
      ['постель', 'prześcieradło', 'pościel'] => 'Мягкая ткань, удобная в использовании',
      ['посуда', 'naczynia', 'szklanka', 'kubek'] => 'Безопасно для пищевых продуктов',
      ['мебель', 'meble', 'krzesło', 'stół'] => 'Прочная конструкция, долговечность',
      ['хранение', 'przechowywanie', 'organizer'] => 'Удобная организация пространства',
      ['кухня', 'kuchnia', 'kuchenny'] => 'Практичное решение для кухни'
    }
    
    features_map.each do |keywords, feature|
      if keywords.any? { |kw| name_lower.include?(kw) }
        return feature
      end
    end
    
    nil
  end
  
  def self.extract_care_instructions(name_lower)
    care_map = {
      ['пластик', 'plastik'] => 'Можно мыть в посудомоечной машине. Не использовать в микроволновой печи.',
      ['стекло', 'szkło'] => 'Можно мыть в посудомоечной машине. Безопасно для микроволновой печи.',
      ['текстиль', 'tkanina', 'bawełna', 'хлопок'] => 'Стирка при 40°C. Не отбеливать. Гладить при низкой температуре.',
      ['металл', 'metal', 'сталь', 'stal'] => 'Можно мыть в посудомоечной машине. Вытирать насухо после мытья.',
      ['дерево', 'drewno'] => 'Протирать влажной тряпкой. Не мочить. Избегать прямых солнечных лучей.'
    }
    
    care_map.each do |keywords, care|
      if keywords.any? { |kw| name_lower.include?(kw) }
        return care
      end
    end
    
    nil
  end
  
  def self.extract_environmental_info(name_lower)
    env_map = {
      ['пластик', 'plastik'] => 'Изготовлено из перерабатываемого пластика',
      ['стекло', 'szkło'] => 'Стекло на 100% перерабатываемо',
      ['дерево', 'drewno'] => 'Изготовлено из сертифицированной древесины',
      ['текстиль', 'tkanina'] => 'Изготовлено из экологически чистых материалов',
      ['led', 'освещение', 'oświetlenie'] => 'Энергосберегающее LED освещение'
    }
    
    env_map.each do |keywords, env|
      if keywords.any? { |kw| name_lower.include?(kw) }
        return env
      end
    end
    
    nil
  end
end

