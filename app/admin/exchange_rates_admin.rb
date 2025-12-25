# Админ-панель для управления курсами валют
Trestle.resource(:exchange_rates, model: ExchangeRate) do
  menu do
    item :exchange_rates, icon: "fa fa-dollar-sign", priority: 4, label: "Курсы валют", group: "Finance"
  end

  table do
    column :date, header: "Дата"
    column :currency_code, header: "Валюта"
    column :rate, header: "Курс" do |rate|
      number_with_precision(rate.rate, precision: 4)
    end
    column :scale, header: "Масштаб"
    column :rate_per_unit, header: "Курс за 1 ед." do |rate|
      number_with_precision(rate.rate_per_unit, precision: 4)
    end
    column :created_at, align: :center
    actions
  end

  controller do
    def sync
      date = params[:date].present? ? Date.parse(params[:date]) : Date.today
      currencies = params[:currencies] || ['USD', 'EUR', 'PLN']
      
      synced = []
      errors = []
      
      currencies.each do |currency|
        begin
          rate = ExchangeRate.fetch_or_create(currency, date)
          if rate
            synced << "#{currency}: #{rate.rate_per_unit.round(4)}"
          else
            errors << "Не удалось получить курс для #{currency}"
          end
        rescue => e
          errors << "Ошибка для #{currency}: #{e.message}"
        end
      end
      
      if errors.empty?
        flash[:message] = "Курсы обновлены: #{synced.join(', ')}"
      else
        flash[:error] = "Ошибки: #{errors.join(', ')}"
      end
      
      redirect_to admin.collection_path
    end
  end

  routes do
    post :sync, on: :collection
  end

  form do |rate|
    date_field :date
    select :currency_code, [['USD', 'USD'], ['EUR', 'EUR'], ['PLN', 'PLN'], ['RUB', 'RUB']]
    number_field :rate, step: 0.0001
    number_field :official_rate, step: 0.0001
    number_field :scale
  end

end

