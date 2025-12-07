class SwaggerController < ActionController::Base
  # Включаем защиту от CSRF для формы авторизации
  protect_from_forgery with: :exception
  
  # Используем layout
  layout 'application'
  
  # Показываем форму авторизации
  def login
    # Если уже авторизован, перенаправляем на Swagger
    if session[:swagger_authenticated] == true
      redirect_to '/api-docs', notice: 'Вы уже авторизованы'
      return
    end
    
    if request.post?
      user = User.find_by(username: params[:username])
      
      if user&.authenticate(params[:password]) && user.is_active? && user.role == 'admin'
        # Устанавливаем сессию
        session[:swagger_authenticated] = true
        session[:swagger_user_id] = user.id
        
        # Перенаправляем на Swagger
        redirect_to '/api-docs', notice: 'Успешный вход'
        return
      else
        flash.now[:alert] = 'Неверные учетные данные или недостаточно прав'
        render :login, status: :unauthorized
      end
    else
      render :login
    end
  end
  
  # Выход
  def logout
    session[:swagger_authenticated] = nil
    session[:swagger_user_id] = nil
    redirect_to '/api-docs/login', notice: 'Вы вышли из системы'
  end
  
end

