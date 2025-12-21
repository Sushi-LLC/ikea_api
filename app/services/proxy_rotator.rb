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
      return yield(nil) if list.empty?
      
      last_error = nil
      proxy_index = @current_index
      
      list.length.times do |attempt|
        proxy = list[proxy_index]
        
        begin
          return yield(parse_proxy(proxy))
        rescue => e
          last_error = e
          
          # Если 403 ошибка и есть еще прокси - пробуем следующий
          if (e.message.include?('403') || 
              (e.respond_to?(:response) && e.response&.code == 403)) && 
             attempt < list.length - 1
            proxy_index = (proxy_index + 1) % list.length
            next
          end
          
          raise e if attempt == list.length - 1
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


