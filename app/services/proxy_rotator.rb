# Сервис для ротации прокси-серверов
class ProxyRotator
  MAX_RETRIES = 5
  
  @current_index = 0
  @mutex = Mutex.new

  class << self
    # Получить список прокси (читается динамически из ENV)
    def proxy_list
      ENV.fetch('PROXY_LIST', '').split(',').map(&:strip).reject(&:empty?)
    end

    # Получить следующий прокси (round-robin)
    def get_proxy
      list = proxy_list
      return nil if list.empty?
      
      @mutex.synchronize do
        proxy = list[@current_index]
        @current_index = (@current_index + 1) % list.length
        proxy
      end
    end

    # Выполнить запрос с ретраями через разные прокси
    def with_proxy_retry(&block)
      list = proxy_list
      
      # Если прокси нет, пробуем без прокси
      if list.empty?
        Rails.logger.warn "ProxyRotator: PROXY_LIST is empty, trying without proxy"
        begin
          return yield(nil)
        rescue => e
          Rails.logger.error "ProxyRotator: Request without proxy failed: #{e.message}"
          raise StandardError.new("Request failed and no proxies configured: #{e.message}")
        end
      end
      
      last_error = nil
      proxy_index = @current_index
      
      # Пробуем каждый прокси
      list.length.times do |attempt|
        proxy = list[proxy_index]
        Rails.logger.info "ProxyRotator: Attempt #{attempt + 1}/#{list.length} with proxy: #{proxy.split('@').last rescue proxy}"
        
        begin
          result = yield(parse_proxy(proxy))
          # Успех - обновляем индекс для следующего запроса
          @mutex.synchronize do
            @current_index = (proxy_index + 1) % list.length
          end
          return result
        rescue => e
          last_error = e
          error_msg = e.message.to_s
          
          Rails.logger.warn "ProxyRotator: Proxy #{proxy_index + 1} failed: #{error_msg[0..200]}"
          
          # Если 403 ошибка или Cloudflare блокировка и есть еще прокси - пробуем следующий
          is_blocked = error_msg.include?('403') || 
                       error_msg.include?('Cloudflare') ||
                       error_msg.include?('Forbidden')
          
          if is_blocked && attempt < list.length - 1
            proxy_index = (proxy_index + 1) % list.length
            # Небольшая задержка перед следующей попыткой
            sleep(0.5)
            next
          end
          
          # Если это последняя попытка или не 403 - пробрасываем ошибку
          if attempt == list.length - 1
            Rails.logger.error "ProxyRotator: All proxies failed. Last error: #{error_msg}"
            raise StandardError.new("All proxies failed. Last error: #{error_msg}")
          end
        end
      end
      
      raise last_error || StandardError.new('All proxies failed')
    end

    private

    def parse_proxy(proxy_url)
      return nil unless proxy_url
      
      uri = URI.parse(proxy_url)
      {
        http_proxyaddr: uri.host,
        http_proxyport: uri.port,
        http_proxyuser: uri.user,
        http_proxypass: uri.password
      }
    end
  end
end


