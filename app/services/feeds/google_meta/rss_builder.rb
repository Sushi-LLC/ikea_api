module Feeds
  module GoogleMeta
    class RssBuilder
      attr_reader :scope, :settings

      def initialize(scope:, settings:)
        @scope = scope
        @settings = settings
      end

      def self.call(scope:, settings:)
        new(scope: scope, settings: settings).call
      end

      def call
        Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.rss(version: "2.0", "xmlns:g" => "http://base.google.com/ns/1.0") do
            xml.channel do
              xml.title(channel_title)
              xml.link(settings.base_url_root)
              xml.description("Google / Meta product feed")
              xml.pubDate(Time.current.rfc2822)
              build_items(xml)
            end
          end
        end.to_xml
      end

      private

      def build_items(xml)
        each_presenter do |presenter|
          xml.item do
            xml["g"].id(presenter.id)
            xml["g"].title(presenter.title)
            xml["g"].description(presenter.description)
            xml.link(presenter.link_url)
            xml["g"].image_link(presenter.image_url)
            presenter.additional_image_urls.each do |url|
              xml["g"].additional_image_link(url)
            end
            xml["g"].availability(presenter.availability_for_google)
            xml["g"].price("#{formatted_price(presenter.price_amount)} #{presenter.currency}")
            xml["g"].condition("new")
            xml["g"].brand(presenter.brand)
            xml["g"].product_type(presenter.product_type) if presenter.product_type.present?
          end
        end
      end

      def each_presenter
        scope.find_each do |product|
          presenter = Feeds::ProductPresenter.new(product: product, settings: settings)
          next unless presenter.valid?
          next if exclude_out_of_stock?(presenter)

          yield presenter
        end
      end

      def exclude_out_of_stock?(presenter)
        !settings.include_out_of_stock? && presenter.availability_key == "out_of_stock"
      end

      def formatted_price(amount)
        sprintf("%.2f", amount)
      end

      def channel_title
        settings.store_name.presence || "Product feed"
      end
    end
  end
end
