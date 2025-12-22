# Админ-панель для расчета цен
Trestle.resource(:price_calculator, model: ParserControl) do
  menu do
    item :price_calculator, icon: "fa fa-calculator", priority: 5, label: "Калькулятор цен", group: "Финансы"
  end

  controller do
    def show
      @calculation = nil
      @error = nil
      
      if params[:calculate]
        begin
          product_price = params[:product_price]&.to_f
          weight = params[:weight]&.to_f
          use_gls = params[:use_gls] == '1'
          date = params[:date].present? ? Date.parse(params[:date]) : Date.today
          
          if product_price && product_price > 0 && weight && weight > 0
            @calculation = PriceCalculationService.calculate(
              product_price,
              weight,
              use_gls_pickup: use_gls,
              date: date
            )
            
            if @calculation[:error]
              @error = @calculation[:error]
              @calculation = nil
            end
          else
            @error = "Укажите цену товара (в злотых) и вес (в кг)"
          end
        rescue => e
          @error = "Ошибка расчета: #{e.message}"
          Rails.logger.error "Price calculation error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        end
      end
      
      render "trestle/price_calculator/show"
    end
  end
end

