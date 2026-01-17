class FeedsController < ApplicationController
  before_action :load_feed_settings
  before_action :ensure_feeds_enabled
  before_action :authorize_access

  def google
    render_feed(
      body: Feeds::GoogleMeta::RssBuilder.call(scope: product_scope, settings: @feed_settings),
      content_type: "application/rss+xml; charset=utf-8"
    )
  end

  def yandex
    render_feed(
      body: Feeds::Yandex::YmlBuilder.call(scope: product_scope, settings: @feed_settings),
      content_type: "application/xml; charset=utf-8"
    )
  end

  private

  def load_feed_settings
    @feed_settings = FeedSetting.instance
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("FeedsController: could not load settings: #{e.message}")
    head :internal_server_error
  end

  def ensure_feeds_enabled
    return head(:not_found) unless @feed_settings&.feeds_enabled?
  end

  def authorize_access
    return unless @feed_settings&.token_feed_access_mode?

    provided = params[:token].to_s
    token = @feed_settings.feed_token.to_s
    return head(:not_found) unless token.present? && provided.present? &&
                                  ActiveSupport::SecurityUtils.secure_compare(token, provided)
  end

  def product_scope
    @product_scope ||= Feeds::ProductScope.call(settings: @feed_settings)
  end

  def render_feed(body:, content_type:)
    expires_in 30.minutes, public: !@feed_settings.token_feed_access_mode?
    render plain: body, content_type: content_type
  end
end
