class DeliveryTrackingService
  def self.call(order)
    return nil unless order.track_number.present?

    case order.delivery_type
    when 'europost'
      EuropostTracker.track(order.track_number)
    when 'autolight'
      AutolightTracker.track(order.track_number)
    else
      { status: 'Информация об отслеживании недоступна', provider: order.delivery_type }
    end
  end
end

class EuropostTracker
  def self.track(track_number)
    # Stub: Europost API typically requires a key and specific request structure.
    # We provide a link and a mock status.
    {
      status: 'В пути (заглушка)',
      last_update: Time.current.strftime('%d.%m.%Y %H:%M'),
      provider: 'Европочта',
      tracking_url: "https://evropochta.by/tracking/?number=#{track_number}"
    }
  end
end

class AutolightTracker
  def self.track(track_number)
    # Stub: Autolight integration usually via https://autolight.by/services/it-services/integration/
    {
      status: 'Прибыло в пункт выдачи (заглушка)',
      last_update: Time.current.strftime('%d.%m.%Y %H:%M'),
      provider: 'Автолайт',
      tracking_url: "https://autolight.by/services/it-services/tracking/?track=#{track_number}"
    }
  end
end
