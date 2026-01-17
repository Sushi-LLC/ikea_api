FeedSettingsAdmin = Trestle.resource :feed_setting, model: FeedSetting, singleton: true do
  menu do
    item :feed_settings, icon: "fa fa-rss", label: "Фиды", group: "Catalog"
  end

  controller do
    def update
      feed_setting = admin.find_instance(params)

      if feed_setting.update(feed_setting_params)
        flash[:message] = "Настройки фидов сохранены"
        redirect_to admin.instance_path(feed_setting)
      else
        flash.now[:error] = "Ошибка: #{feed_setting.errors.full_messages.join(', ')}"
        render :edit
      end
    end

    private

    def feed_setting_params
      params.require(:feed_setting).permit(
        :feeds_enabled,
        :feed_access_mode,
        :feed_token,
        :base_url,
        :currency_default,
        :store_name,
        :store_company,
        :store_platform_brand,
        :availability_mapping_json,
        :yml_delivery_cost,
        :yml_delivery_days,
        :include_out_of_stock
      )
    end
  end

  form do |feed_setting|
    row do
      col(sm: 4) { check_box :feeds_enabled, label: "Фиды включены" }
      col(sm: 4) do
        select :feed_access_mode,
               FeedSetting.feed_access_modes.keys.map { |mode| [mode.capitalize, mode] },
               label: "Режим доступа"
      end
      col(sm: 4) do
        text_field :feed_token,
                   label: "Токен доступа",
                   placeholder: "Оставьте пустым для публичного доступа"
      end
    end

    row do
      col(sm: 12) do
        text_field :base_url, label: "Базовый URL", placeholder: "https://example.com"
      end
    end

    row do
      col(sm: 4) { text_field :currency_default, label: "Валюта по умолчанию" }
      col(sm: 4) { text_field :store_name, label: "Название магазина (YML)" }
      col(sm: 4) { text_field :store_company, label: "Компания (YML)" }
    end

    row do
      col(sm: 6) { text_field :store_platform_brand, label: "Бренд (Google/Meta)" }
      col(sm: 6) { check_box :include_out_of_stock, label: "Показывать отсутствующие" }
    end

    row do
      col(sm: 12) do
        text_area :availability_mapping_json,
                  label: "Map наличия",
                  value: feed_setting.availability_mapping_json,
                  rows: 4,
                  help: "JSON, например {\"in_stock\":\"in stock\",\"out_of_stock\":\"out of stock\"}"
      end
    end

    row do
      col(sm: 6) do
        number_field :yml_delivery_cost, label: "Стоимость доставки (YML)", step: 0.01
      end
      col(sm: 6) do
        number_field :yml_delivery_days, label: "Срок доставки (YML), дней"
      end
    end

    row do
      col(sm: 12) do
        render partial: "trestle/feed_settings/feed_links", locals: { feed_setting: feed_setting }
      end
    end
  end
end
