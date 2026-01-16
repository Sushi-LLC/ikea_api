module Api
  module V1
    class HomepageController < ApplicationController
      def slider_main
        banners = HomeBanner.active
                           .main
                           .by_position
                           .includes(:category, :image_attachment)
        
        render json: HomeBannerSerializer.new(banners, {
          include: [:category],
          params: { base_url: request.protocol + request.host_with_port }
        })
      end

      def slider_banners
        banners = HomeBanner.active
                           .secondary
                           .by_position
                           .includes(:category, :image_attachment)
        
        render json: HomeBannerSerializer.new(banners, {
          include: [:category],
          params: { base_url: request.protocol + request.host_with_port }
        })
      end
    end
  end
end
