class SwaggerAuthMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Проверяем, является ли запрос к Swagger UI
    if request.path.start_with?('/api-docs') && 
       !request.path.start_with?('/api-docs/login') &&
       !request.path.start_with?('/api-docs/logout') &&
       !request.path.include?('/v1/swagger.yaml') &&
       !request.path.include?('/v1/swagger.json') &&
       !request.path.include?('.js') &&
       !request.path.include?('.css') &&
       !request.path.include?('.png') &&
       !request.path.include?('.ico')
      
      # Проверяем сессию (теперь она доступна, т.к. middleware после Session)
      authenticated = false
      begin
        # Пропускаем проверку для POST запросов (они обрабатываются контроллером)
        if request.get?
          session = request.session
          if session && session.respond_to?(:[])
            authenticated = session[:swagger_authenticated] == true
          end
        else
          # Для POST и других методов пропускаем проверку (контроллер сам обработает)
          authenticated = true
        end
      rescue => e
        # Если сессия недоступна, считаем неавторизованным
        authenticated = false
      end
      
      unless authenticated
        # Если это GET запрос, перенаправляем на форму входа
        if request.get?
          return [302, { 'Location' => '/api-docs/login', 'Content-Type' => 'text/html' }, []]
        end
      end
    end
    
    @app.call(env)
  end
end

