module Feeds
  module Yandex
    class YmlBuilder
      attr_reader :scope, :settings

      def initialize(scope:, settings:)
        @scope = scope
        @settings = settings
      end

      def self.call(scope:, settings:)
        new(scope: scope, settings: settings).call
      end

      def call
        presenters = build_presenters

        Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.yml_catalog(date: Time.current.strftime("%Y-%m-%d %H:%M")) do
            xml.shop do
              xml.name(settings.store_name)
              xml.company(settings.store_company)
              xml.url(settings.base_url_root)
              xml.currencies { currency_nodes(xml) }
              xml.categories { category_nodes(xml, presenters) }
              xml.offers { offer_nodes(xml, presenters) }
            end
          end
        end.to_xml
      end

      private

      def build_presenters
        presenters = []

        scope.find_each do |product|
          presenter = Feeds::ProductPresenter.new(product: product, settings: settings)
          next unless presenter.valid?
          next unless presenter.available_for_yandex?

          presenters << presenter
        end

        presenters
      end

      def currency_nodes(xml)
        xml.currency(id: "BYN", rate: "1")
        extra_currency = settings.currency_default&.upcase
        if extra_currency.present? && extra_currency != "BYN"
          xml.currency(id: extra_currency, rate: "1")
        end
      end

      def category_nodes(xml, presenters)
        unique_categories(presenters).each do |category|
          attributes = { id: category.ikea_id }
          parent_id = Category.normalize_parent_ids(category.parent_ids).last
          attributes[:parentId] = parent_id if parent_id.present?
          xml.category(attributes) { xml.text(category.name) }
        end
      end

      def offer_nodes(xml, presenters)
        presenters.each do |presenter|
          xml.offer(id: presenter.id, available: presenter.available_for_yandex?) do
            xml.url(presenter.link_url)
            xml.price(formatted_price(presenter.price_amount))
            xml.currencyId(presenter.currency)
            xml.categoryId(presenter.category_id)
            xml.name(presenter.title)
            picture_urls_for(presenter).each { |picture| xml.picture(picture) }
            xml.description { xml.cdata(presenter.description) }
            xml.vendor(presenter.brand) if presenter.brand.present?
            add_delivery(xml)
          end
        end
      end

      def unique_categories(presenters)
        presenters.map(&:category).compact.uniq { |category| category.ikea_id.presence || category.id }
      end

      def picture_urls_for(presenter)
        ([presenter.image_url] + presenter.additional_image_urls).compact
      end

      def formatted_price(amount)
        sprintf("%.2f", amount)
      end

      def add_delivery(xml)
        return unless settings.yml_delivery_cost.present? || settings.yml_delivery_days.present?

        xml.delivery(true)
        xml.send("delivery-options") do
          attrs = {}
          attrs[:cost] = settings.yml_delivery_cost unless settings.yml_delivery_cost.nil?
          attrs[:days] = settings.yml_delivery_days unless settings.yml_delivery_days.nil?
          xml.option(attrs)
        end
      end
    end
  end
end
