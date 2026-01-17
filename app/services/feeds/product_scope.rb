module Feeds
  class ProductScope
    attr_reader :settings

    def initialize(settings:)
      @settings = settings
    end

    def self.call(settings:)
      new(settings: settings).call
    end

    def call
      Product.includes(:category)
             .where.not(price: nil)
             .where.not(url: [nil, ""])
             .where.not(category_id: [nil, ""])
             .where("COALESCE(images, local_images) IS NOT NULL")
             .order(updated_at: :desc)
    end
  end
end
