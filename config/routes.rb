Rails.application.routes.draw do
  get '/up', to: 'health#check'
  
  # Swagger авторизация
  get '/api-docs/login', to: 'swagger#login'
  post '/api-docs/login', to: 'swagger#login'
  get '/api-docs/logout', to: 'swagger#logout'
  
  mount Rswag::Api::Engine => '/api-docs'
  mount Rswag::Ui::Engine => '/api-docs'
  
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
    end
  end
end
