class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  
  def authenticate_user
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token
      decoded = JwtService.decode(token)
      @current_user = User.find(decoded[:user_id]) if decoded
    end
    
    render json: { error: 'Не авторизован' }, status: :unauthorized unless @current_user
  end

  def authenticate_user_optional
    token = request.headers['Authorization']&.split(' ')&.last
    return unless token
    
    decoded = JwtService.decode(token)
    @current_user = User.find_by(id: decoded[:user_id]) if decoded
  rescue => _e
    # Token invalid or expired, just ignore for optional auth
    nil
  end
  
  def current_user
    @current_user
  end
end
