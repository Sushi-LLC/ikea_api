# Админ-панель для расчета таможенной пошлины
Trestle.resource(:customs_duty_calculator, model: CustomsDutyCalculator) do
  menu do
    item :customs_duty_calculator, icon: "fa fa-file-invoice-dollar", priority: 4, label: "Калькулятор таможенной пошлины", group: "Finance"
  end

  controller do
    def index
      redirect_to admin.instance_path(CustomsDutyCalculator.new(id: 'show'))
    end
    
    def show
      @calculation = nil
      @error = nil
      
      if params[:calculate]
        begin
          cost_eur = params[:cost_eur]&.to_f
          weight_kg = params[:weight_kg]&.to_f
          date = params[:date].present? ? Date.parse(params[:date]) : Date.today
          
          if cost_eur && cost_eur > 0 && weight_kg && weight_kg > 0
            # Получаем курс евро
            exchange_rate = ExchangeRate.fetch_or_create('EUR', date)
            eur_rate = exchange_rate&.rate_per_unit
            
            if eur_rate.nil?
              @error = "Не удалось получить курс евро на дату #{date}. Проверьте наличие курсов валют в системе."
            else
              @calculation = CustomsDutyService.calculate(cost_eur, weight_kg, eur_rate)
              @calculation[:cost_eur] = cost_eur
              @calculation[:weight_kg] = weight_kg
              @calculation[:eur_rate] = eur_rate
              @calculation[:date] = date
              
              # Получаем лимиты для отображения
              @calculation[:free_cost_limit] = CustomsDutyService.free_cost_limit
              @calculation[:free_weight_limit] = CustomsDutyService.free_weight_limit
              @calculation[:cost_duty_rate] = CustomsDutyService.cost_duty_rate
              @calculation[:weight_duty_rate] = CustomsDutyService.weight_duty_rate
              @calculation[:customs_fee] = CustomsDutyService.customs_fee
            end
          else
            @error = "Укажите стоимость товара (в евро) и вес (в кг)"
          end
        rescue => e
          @error = "Ошибка расчета: #{e.message}"
          Rails.logger.error "Customs duty calculation error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        end
      end
      
      render "trestle/customs_duty_calculator/show"
    end
  end
end

