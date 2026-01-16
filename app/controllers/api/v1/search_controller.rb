module Api
  module V1
    class SearchController < ApplicationController
      def suggest
        query = params[:q].to_s.strip
        suggestions = suggestions_for(query)
        categories = matching_categories(query)
        products = prioritized_products(query)
        popular_queries = PopularSearchQuery.active.matching(query).ordered.limit(5)

        log_search(query, products.size) if query.present?

        render json: {
          suggestions: suggestions,
          categories: CategorySerializer.new(categories).serializable_hash,
          products: ProductSerializer.new(products).serializable_hash,
          popular_queries: popular_queries.map do |entry|
            { query: entry.query, weight: entry.weight }
          end
        }
      end

      private

      def suggestions_for(query)
        return [] if query.blank?

        pattern = "#{query}%"
        products = Product.where("name_ru ILIKE :pattern", pattern: pattern)
                          .limit(30)
        categories = Category.where("translated_name ILIKE :pattern", pattern: pattern)
                             .limit(20)

        names = products.map(&:name_ru)
        names += categories.map(&:translated_name)

        names.compact.map(&:strip).reject(&:blank?).uniq.take(5)
      end

      def matching_categories(query)
        return Category.none if query.blank?

        Category.active
                .where("name ILIKE :term OR translated_name ILIKE :term", term: "%#{query}%")
                .limit(5)
      end

      def prioritized_products(query)
        return Product.none if query.blank?

        exact_matches = Product.where("LOWER(sku) = ?", query.downcase).limit(1).to_a
        exact_ids = exact_matches.map(&:id)

        fuzzies = Product.where("name ILIKE :term OR name_ru ILIKE :term", term: "%#{query}%")
                         .where.not(id: exact_ids)
                         .limit([10 - exact_matches.size, 0].max)

        (exact_matches + fuzzies.to_a).take(10)
      end

      def log_search(query, results_count)
        SearchQueryLog.create!(
          customer: current_user,
          query: query,
          results_count: results_count
        )
      end
    end
  end
end
