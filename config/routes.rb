Rails.application.routes.draw do
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
      resources :products, only: [:index, :show], param: :sku do
        collection do
          get :bestsellers
          get :popular
        end

        resources :reviews, only: [:create]
      end

      resources :reviews, only: [:update, :destroy] do
        member do
          post :helpful
          delete :helpful, action: :remove_helpful
        end
      end

      namespace :account do
        resources :reviews, only: [:index] do
          collection do
            get :available
          end
        end
        resources :orders, only: [:index, :show]
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
      # resources :filters, only: [:index]
      
      # Delivery
      # resources :delivery, only: [] do
      #   collection do
      #     get :types
      #     post :calculate
      #   end
      # end
      
      # Auth
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      post 'auth/phone/send', to: 'auth#send_phone_code'
      post 'auth/phone/verify', to: 'auth#verify_phone_code'
      
      # Search
      resources :search, only: [] do
        collection do
          get :suggest
        end
      end

      # Homepage
      get 'homepage/slider/main', to: 'homepage#slider_main'
      get 'homepage/slider/banners', to: 'homepage#slider_banners'

      # Cart
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

      # Content
      namespace :content do
        resources :articles, only: [:index, :show], param: :slug
      end

      # Reviews Export (API version)
      get 'reviews/export(.:format)', to: 'reviews_exports#index'
      
      # Checkout
      post 'checkout', to: 'checkout#create'
    end
  end

  # System & Feeds
  get '/up', to: 'health#check'
  get '/feeds/google.xml', to: 'feeds#google'
  get '/feeds/yandex.yml', to: 'feeds#yandex'
end
