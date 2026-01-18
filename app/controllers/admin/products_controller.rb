# app/controllers/admin/products_controller.rb
class Admin::ProductsController < ApplicationController
  # Если у вас есть стандартная админ-авторизация — подключи её тут, как в остальных админ-контроллерах.
  # before_action :authenticate_admin!

  # GET /admin/products/by_category?category_id=12345
  #
  # Возвращает упрощённый список товаров для выпадающих списков/автокомплита:
  # [{ sku: "...", name: "..." }, ...]
  #
  # category_id — это ikea_id категории (Category.primary_key = 'ikea_id')
  def by_category
    category_ikea_id = params[:category_id].to_s.strip
    return render(json: []) if category_ikea_id.blank?

    # В проекте Product имеет:
    # has_many :categories, through: :category_products
    # Category.primary_key = 'ikea_id'
    products = Product
      .joins(:categories)
      .where(categories: { ikea_id: category_ikea_id })
      .distinct
      .order(:name)
      .limit(500)

    render json: products.map { |p|
      {
        sku: p.sku,
        name: (p.name.presence || p.sku)
      }
    }
  end
end
