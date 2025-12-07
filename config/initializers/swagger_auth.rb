# Middleware для авторизации Swagger
require_relative '../../app/middleware/swagger_auth_middleware'

# Вставляем ПОСЛЕ Session middleware, чтобы сессия была доступна
Rails.application.config.middleware.insert_after ActionDispatch::Flash, SwaggerAuthMiddleware

