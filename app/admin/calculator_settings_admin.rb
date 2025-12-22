# Админ-панель для управления настройками калькулятора
Trestle.resource(:calculator_settings, model: CalculatorSetting) do
  menu do
    item :calculator_settings, icon: "fa fa-cog", priority: 6, label: "Настройки калькулятора", group: "Финансы"
  end

  table do
    column :key, header: "Ключ"
    column :description, header: "Описание"
    column :setting_type, header: "Тип"
    column :value, header: "Значение" do |setting|
      case setting.setting_type
      when 'json'
        content_tag(:pre, JSON.pretty_generate(setting.json_value), style: "max-width: 300px; font-size: 0.85em;")
      else
        setting.value
      end
    end
    column :updated_at, header: "Обновлено"
    actions
  end

  form do |setting|
    text_field :key, readonly: true
    text_area :description
    select :setting_type, [['Decimal', 'decimal'], ['Integer', 'integer'], ['JSON', 'json']], 
           { prompt: 'Выберите тип' }, { readonly: true }
    
    if setting.setting_type == 'json'
      text_area :value, rows: 10, 
                placeholder: 'Введите JSON, например: {"0-20": 3.0, "20-30": 2.0}',
                value: setting.value.present? ? JSON.pretty_generate(setting.json_value) : ''
    else
      number_field :value, step: 0.0001
    end
  end
  
  controller do
    def index
      super
      render "trestle/calculator_settings/index"
    end
    
    def update
      setting = admin.find_instance(params)
      
      # Если это JSON, валидируем и форматируем
      if setting.setting_type == 'json' && params[:calculator_setting][:value].present?
        begin
          json_value = JSON.parse(params[:calculator_setting][:value])
          params[:calculator_setting][:value] = json_value.to_json
        rescue JSON::ParserError => e
          flash[:error] = "Ошибка парсинга JSON: #{e.message}"
          render :edit
          return
        end
      end
      
      super
    end
    
    def initialize_defaults
      CalculatorSetting.initialize_defaults
      flash[:message] = "Настройки инициализированы значениями по умолчанию"
      redirect_to admin.collection_path
    end
  end

  routes do
    post :initialize_defaults, on: :collection
  end
end

