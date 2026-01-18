Rails.application.routes.draw do
  get '/up', to: 'health#check'
  get '/feeds/google.xml', to: 'feeds#google'
  get '/feeds/yandex.yml', to: 'feeds#yandex'
  
  # Trestle Admin Panel автоматически монтируется на /admin
  # (см. config/initializers/trestle.rb, config.automount = true)
  
  # Swagger авторизация
  get '/api-docs/login', to: 'swagger#login'
  post '/api-docs/login', to: 'swagger#login'
  get '/api-docs/logout', to: 'swagger#logout'
  
  mount Rswag::Api::Engine => '/api-docs'
  mount Rswag::Ui::Engine => '/api-docs'

  namespace :admin do
    get "products/by_category", to: "products#by_category"
  end
  
  namespace :api do
    namespace :v1 do
      # Products
      resources :products, only: [:index, :show] do
        collection do
          get :bestsellers
          get :popular
        end
      end
      
      # Categories
      resources :categories, only: [:index, :show] do
        collection do
          get :popular
          get :tree
          get :map
        end
      end
      
      # Filters
      resources :filters, only: [:index]
      
      # Delivery
      resources :delivery, only: [] do
        collection do
          get :types
          post :calculate
        end
      end
      
      # Auth
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      
      # Homepage
      get 'homepage/slider/main', to: 'homepage#slider_main'
      get 'homepage/slider/banners', to: 'homepage#slider_banners'
      get 'search/suggest', to: 'search#suggest'

      resource :cart, only: [:show] do
        delete :clear, on: :collection
      end

      resources :cart_items, only: [:create] do
        patch ':sku', to: 'cart_items#update', on: :collection
        delete ':sku', to: 'cart_items#destroy', on: :collection
      end

      namespace :cart do
        post 'promo/apply', to: 'cart_promo#apply'
        delete 'promo', to: 'cart_promo#remove'
      end

      namespace :content do
        resources :articles, only: [:index, :show], param: :slug
      end
    end
  end
end
