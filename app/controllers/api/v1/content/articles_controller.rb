module Api
  module V1
    module Content
      class ArticlesController < ApplicationController
        def index
          articles = ContentArticle.visible
          articles = apply_filters(articles)
          articles = articles.includes(:content_article_products, :content_article_categories)

          paged = articles.page(current_page).per(per_page)

          render json: ContentArticleSerializer.new(paged, {
            meta: {
              total: paged.total_count,
              page: current_page,
              per_page: per_page
            }
          })
        end

        def show
          slug = params[:slug] || params[:id]
          article = ContentArticle.visible.find_by!(slug: slug)
          article_products = article.content_article_products.order(:position)
          article_categories = article.content_article_categories.order(:position)

          products_map = Product.where(sku: article_products.pluck(:product_sku)).index_by(&:sku)
          categories_map = Category.where(ikea_id: article_categories.pluck(:category_id)).index_by(&:ikea_id)

          render json: ContentArticleSerializer.new(article, {
            params: {
              detail: true,
              linked_products_ordered: article_products,
              linked_products_map: products_map,
              linked_categories_ordered: article_categories,
              linked_categories_map: categories_map
            }
          })
        end

        private

        def apply_filters(scope)
          scope = scope.where(content_type: ContentArticle.content_types[params[:content_type]]) if params[:content_type].present? && ContentArticle.content_types.key?(params[:content_type])
          scope = scope.where(pinned: true) if params[:pinned_only] == 'true'
          scope = scope.with_component(params[:component]) if params[:component].present?
          scope = scope.with_project(params[:project]) if params[:project].present?
          scope = scope.with_tag(params[:tag]) if params[:tag].present?
          scope
        end

        def current_page
          params[:page].to_i.positive? ? params[:page].to_i : 1
        end

        def per_page
          per = params[:per_page].to_i
          return 20 if per.zero?

          per.clamp(1, 100)
        end
      end
    end
  end
end
