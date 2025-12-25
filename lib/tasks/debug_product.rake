# Временный rake task для отладки парсинга продукта
namespace :debug do
  desc "Отладка парсинга продукта по шагам"
  task :product, [:product_id] => :environment do |t, args|
    begin
      product_id = args[:product_id] || 986
      product = Product.find(product_id)
      
      puts "=" * 80
    puts "ОТЛАДКА ПАРСИНГА ПРОДУКТА #{product_id}"
    puts "=" * 80
    puts ""
    
    # ШАГ 1: Базовые атрибуты
    puts "ШАГ 1: Получение базовых атрибутов"
    puts "-" * 80
    
    pl_details = PlDetailsFetcher.fetch(product.url)
    
    puts "URL: #{product.url}"
    puts "SKU: #{product.sku}"
    puts "item_no: #{product.item_no}"
    puts ""
    puts "Базовые атрибуты из PL:"
    puts "  - Название: #{pl_details[:name] || 'Нет'}"
    puts "  - Цена: #{pl_details[:price] || 'Нет'}"
    puts "  - Вес: #{pl_details[:weight] || 'Нет'}"
    puts "  - Размеры: #{pl_details[:dimensions] || 'Нет'}"
    puts "  - Коллекция: #{pl_details[:collection] || 'Нет'}"
    puts "  - Изображения: #{pl_details[:images]&.length || 0}"
    puts "  - Видео: #{pl_details[:videos]&.length || 0}"
    puts "  - Мануалы: #{pl_details[:manuals]&.length || 0}"
    puts "  - Связанные продукты: #{pl_details[:related_products]&.length || 0}"
    puts "  - Комплекты: #{pl_details[:set_items]&.length || 0}"
    puts "  - Бандлы: #{pl_details[:bundle_items]&.length || 0}"
    puts ""
    
    # ШАГ 2: Получение HTML страницы и поиск модальных окон
    puts "ШАГ 2: Получение HTML страницы и поиск модальных окон"
    puts "-" * 80
    
    # Получаем HTML через PlDetailsFetcher (использует прокси)
    puts "Получаем HTML через PlDetailsFetcher..."
    html = PlDetailsFetcher.new.send(:fetch_with_proxy, product.url)
    
    if html && html.length > 10000
      puts "HTML получен, длина: #{html.length} символов"
      puts ""
      
      # Сохраняем HTML в лог
      Rails.logger.info "=" * 80
      Rails.logger.info "ПОЛНЫЙ HTML СТРАНИЦЫ ПРОДУКТА (HTTP)"
      Rails.logger.info "=" * 80
      Rails.logger.info html[0..50000] # Первые 50KB
      
      # Парсим HTML
      doc = Nokogiri::HTML(html)
      
      # Ищем кнопки модальных окон
      puts "Ищем кнопки модальных окон в HTML..."
      modal_buttons = doc.css('button, a').select do |btn|
        text = btn.text.to_s.downcase
        id = btn['id'].to_s.downcase
        class_name = btn['class'].to_s.downcase
        aria_controls = btn['aria-controls'].to_s.downcase
        parent_id = btn.ancestors('[id]').first&.[]('id').to_s.downcase || ''
        
        text.include?('informacja o produkcie') ||
        text.include?('информация о продукте') ||
        text.include?('wymiary') ||
        text.include?('размеры') ||
        aria_controls.include?('product-details') ||
        aria_controls.include?('dimensions') ||
        parent_id.include?('product-information') ||
        parent_id.include?('measurement') ||
        parent_id.include?('pipf-product-information') ||
        class_name.include?('list-view-item__action') ||
        class_name.include?('pipf-list-view-item')
      end
      
      puts "Найдено кнопок модальных окон: #{modal_buttons.length}"
      puts ""
      
      if modal_buttons.any?
        modal_buttons.each_with_index do |btn, idx|
          puts "Кнопка #{idx + 1}:"
          puts "  Текст: #{btn.text.strip[0..100]}"
          puts "  ID: #{btn['id']}"
          puts "  Class: #{btn['class']}"
          puts "  aria-controls: #{btn['aria-controls']}"
          puts "  Parent ID: #{btn.ancestors('[id]').first&.[]('id')}"
          puts ""
        end
      end
      
      # Ищем модальные окна в HTML (могут быть скрыты)
      puts "Ищем модальные окна в HTML..."
      modal_selectors = [
        '.pipf-product-details-modal',
        '[class*="product-details-modal"]',
        '[id*="product-details"]',
        '[aria-labelledby*="pip-modal-header"]',
        '[aria-modal="true"]',
        '.pipf-sheets',
        '[role="dialog"]'
      ]
      
      modals_found = []
      modal_selectors.each do |selector|
        modals = doc.css(selector)
        modals.each do |modal|
          modals_found << {
            selector: selector,
            html: modal.to_html,
            text: modal.text.strip[0..500]
          }
        end
      end
      
      puts "Найдено модальных окон в HTML: #{modals_found.length}"
      puts ""
      
      if modals_found.any?
        modals_found.each_with_index do |modal, idx|
          puts "=" * 80
          puts "МОДАЛЬНОЕ ОКНО #{idx + 1} (селектор: #{modal[:selector]})"
          puts "=" * 80
          puts "Текст (первые 500 символов):"
          puts modal[:text]
          puts ""
          puts "HTML (первые 2000 символов):"
          puts modal[:html][0..2000]
          puts ""
          
          # Сохраняем полный HTML в лог
          Rails.logger.info "=" * 80
          Rails.logger.info "МОДАЛЬНОЕ ОКНО #{idx + 1} - #{modal[:selector]}"
          Rails.logger.info "=" * 80
          Rails.logger.info modal[:html]
        end
      else
        puts "Модальные окна не найдены в статическом HTML"
        puts "Пробуем использовать headless браузер..."
        puts ""
        
        # Пробуем headless браузер
        require 'ferrum'
        
        browser = nil
        begin
      # Пока работаем без прокси для отладки
      browser_options = {
        'no-sandbox' => nil,
        'disable-dev-shm-usage' => nil,
        'disable-gpu' => nil,
        'window-size' => '1400,900'
      }
      
      browser = Ferrum::Browser.new(
        headless: true,
        browser_options: browser_options,
        timeout: 60,
        window_size: [1400, 900]
      )
      
      puts "Загружаем страницу: #{product.url}"
      browser.go_to(product.url)
      
      # Ждем загрузки
      puts "Ожидание загрузки страницы..."
      browser.network.wait_for_idle(timeout: 30)
      sleep(10) # Дополнительное время для загрузки JS
      
      # Проверяем Cloudflare
      page_html = browser.body
      if page_html.include?('Just a moment...') || page_html.include?('Checking your browser') || page_html.length < 10000
        puts "Обнаружена защита Cloudflare или неполная загрузка, ждем дольше..."
        sleep(15)
        browser.network.wait_for_idle(timeout: 30)
        sleep(10)
        page_html = browser.body
      end
      
      puts "Страница загружена. HTML длина: #{page_html.length}"
      
      # Сохраняем полный HTML в лог для анализа
      Rails.logger.info "=" * 80
      Rails.logger.info "ПОЛНЫЙ HTML СТРАНИЦЫ ПРОДУКТА"
      Rails.logger.info "=" * 80
      Rails.logger.info page_html
      
      puts ""
      
      # Ищем все кнопки, которые могут открывать модальные окна
      buttons_info = browser.evaluate(<<~JS)
        (function() {
          const buttons = Array.from(document.querySelectorAll('button, a, [role="button"]'));
          const allButtons = buttons.map((btn, idx) => {
            const text = btn.textContent || '';
            const id = btn.id || '';
            const className = btn.className || '';
            const ariaControls = btn.getAttribute('aria-controls') || '';
            const parentId = btn.closest('[id]')?.id || '';
            const dataAttr = btn.getAttribute('data-skapa') || '';
            
            return {
              index: idx,
              text: text.trim().substring(0, 150),
              id: id,
              className: className.substring(0, 150),
              ariaControls: ariaControls,
              parentId: parentId,
              dataAttr: dataAttr,
              tagName: btn.tagName
            };
          });
          
          // Фильтруем кнопки, связанные с модальными окнами
          const modalButtons = allButtons.filter(btn => {
            const text = btn.text.toLowerCase();
            const className = btn.className.toLowerCase();
            const parentId = btn.parentId.toLowerCase();
            
            return text.includes('информация о продукте') ||
                   text.includes('informacja o produkcie') ||
                   text.includes('размеры') ||
                   text.includes('wymiary') ||
                   text.includes('product information') ||
                   text.includes('product details') ||
                   btn.ariaControls.includes('product-details') ||
                   btn.ariaControls.includes('dimensions') ||
                   parentId.includes('product-information') ||
                   parentId.includes('measurement') ||
                   parentId.includes('pipf-product-information') ||
                   className.includes('list-view-item__action') ||
                   className.includes('modal') ||
                   className.includes('details') ||
                   className.includes('pipf-list-view-item');
          });
          
          return {
            totalButtons: buttons.length,
            allButtons: allButtons.slice(0, 20), // Первые 20 для отладки
            modalButtons: modalButtons
          };
        })();
      JS
      
      puts "Найдено кнопок на странице: #{buttons_info['totalButtons']}"
      puts "Найдено кнопок модальных окон: #{buttons_info['modalButtons']&.length || 0}"
      puts ""
      
      # Выводим все найденные кнопки для отладки
      if buttons_info['allButtons'] && buttons_info['allButtons'].length > 0
        puts "Первые 20 кнопок на странице:"
        buttons_info['allButtons'].each_with_index do |btn, idx|
          puts "  #{idx + 1}. [#{btn['tagName']}] #{btn['text'][0..80]}"
          puts "     ID: #{btn['id']}, Class: #{btn['className'][0..60]}"
        end
        puts ""
      end
      
      if buttons_info['modalButtons'] && buttons_info['modalButtons'].length > 0
        buttons_info['modalButtons'].each_with_index do |btn_info, idx|
          puts "Кнопка #{idx + 1}:"
          puts "  Текст: #{btn_info['text']}"
          puts "  ID: #{btn_info['id']}"
          puts "  Class: #{btn_info['className']}"
          puts "  aria-controls: #{btn_info['ariaControls']}"
          puts "  Parent ID: #{btn_info['parentId']}"
          puts ""
        end
      end
      
      # Открываем каждое модальное окно по очереди
      modals_found = []
      
      if buttons_info['modalButtons'] && buttons_info['modalButtons'].length > 0
        buttons_info['modalButtons'].each_with_index do |btn_info, idx|
          puts "=" * 80
          puts "ОТКРЫВАЕМ МОДАЛЬНОЕ ОКНО #{idx + 1}"
          puts "=" * 80
          
          # Находим и кликаем кнопку
          clicked = browser.evaluate(<<~JS)
            (function() {
              const buttons = Array.from(document.querySelectorAll('button, a'));
              const targetButton = buttons[#{btn_info['index']}];
              if (targetButton) {
                targetButton.click();
                return true;
              }
              return false;
            })();
          JS
          
          if clicked
            puts "Кнопка кликнута, ждем открытия модального окна..."
            sleep(3)
            browser.network.wait_for_idle(timeout: 10)
            sleep(2)
            
            # Получаем HTML модального окна
            modal_html = browser.evaluate(<<~JS)
              (function() {
                const modalSelectors = [
                  '.pipf-product-details-modal',
                  '[class*="product-details-modal"]',
                  '[id*="product-details"]',
                  '[aria-labelledby*="pip-modal-header"]',
                  '[aria-modal="true"]',
                  '.pipf-sheets',
                  '[role="dialog"]',
                  '[class*="dimensions"]',
                  '[class*="measurement"]'
                ];
                
                for (const selector of modalSelectors) {
                  const modal = document.querySelector(selector);
                  if (modal && modal.offsetParent !== null) {
                    return {
                      found: true,
                      selector: selector,
                      html: modal.outerHTML,
                      text: modal.innerText.substring(0, 500)
                    };
                  }
                }
                
                return { found: false };
              })();
            JS
            
            if modal_html && modal_html['found']
              puts "Модальное окно найдено (селектор: #{modal_html['selector']})"
              puts ""
              puts "Текст модального окна (первые 500 символов):"
              puts modal_html['text']
              puts ""
              puts "HTML модального окна (первые 2000 символов):"
              puts modal_html['html'][0..2000]
              puts ""
              
              # Сохраняем полный HTML в лог
              Rails.logger.info "=" * 80
              Rails.logger.info "МОДАЛЬНОЕ ОКНО #{idx + 1} - #{btn_info['text']}"
              Rails.logger.info "=" * 80
              Rails.logger.info modal_html['html']
              
              modals_found << {
                index: idx + 1,
                button_text: btn_info['text'],
                selector: modal_html['selector'],
                html: modal_html['html']
              }
              
              # Закрываем модальное окно
              close_clicked = browser.evaluate(<<~JS)
                (function() {
                  const closeButtons = document.querySelectorAll(
                    'button[aria-label*="Закрыть"], ' +
                    'button[aria-label*="Close"], ' +
                    '.pipf-modal-header__close, ' +
                    '[class*="close"]'
                  );
                  if (closeButtons.length > 0) {
                    closeButtons[0].click();
                    return true;
                  }
                  return false;
                })();
              JS
              
              if close_clicked
                puts "Модальное окно закрыто"
                sleep(1)
              else
                puts "Не удалось закрыть модальное окно автоматически"
              end
            else
              puts "Модальное окно не найдено после клика"
            end
          else
            puts "Не удалось кликнуть кнопку"
          end
          
          puts ""
        end
      else
        puts "Кнопки модальных окон не найдены. Ищем модальные окна в HTML..."
        
        # Пробуем найти модальные окна, которые могут быть уже в DOM
        existing_modals = browser.evaluate(<<~JS)
          (function() {
            const modalSelectors = [
              '.pipf-product-details-modal',
              '[class*="product-details-modal"]',
              '[id*="product-details"]',
              '[aria-labelledby*="pip-modal-header"]',
              '[aria-modal="true"]',
              '.pipf-sheets',
              '[role="dialog"]'
            ];
            
            const modals = [];
            modalSelectors.forEach(selector => {
              const elements = document.querySelectorAll(selector);
              elements.forEach((el, idx) => {
                modals.push({
                  selector: selector,
                  index: idx,
                  html: el.outerHTML,
                  text: el.innerText.substring(0, 500)
                });
              });
            });
            
            return modals;
          })();
        JS
        
        if existing_modals && existing_modals.length > 0
          puts "Найдено модальных окон в DOM: #{existing_modals.length}"
          existing_modals.each_with_index do |modal, idx|
            puts ""
            puts "Модальное окно #{idx + 1} (селектор: #{modal['selector']}):"
            puts "Текст (первые 500 символов):"
            puts modal['text']
            puts ""
            Rails.logger.info "=" * 80
            Rails.logger.info "МОДАЛЬНОЕ ОКНО В DOM #{idx + 1}"
            Rails.logger.info "=" * 80
            Rails.logger.info modal['html']
          end
        else
          puts "Модальные окна не найдены в DOM"
        end
      end
        rescue => e
          puts "ОШИБКА при работе с headless браузером: #{e.class} - #{e.message}"
          puts e.backtrace.first(5).join("\n")
        ensure
          browser&.quit rescue nil
        end
      end
    else
      puts "HTML не получен или слишком короткий (#{html&.length || 0} символов)"
    end
    
    # ШАГ 3: Составляем список доступных атрибутов
      puts ""
      puts "=" * 80
      puts "ШАГ 3: Составление списка доступных атрибутов"
      puts "=" * 80
      puts ""
      
      # Анализируем все найденные модальные окна
      all_attributes = {}
      
      # Базовые атрибуты
      all_attributes['Базовые'] = {
        'Название' => pl_details[:name],
        'Цена' => pl_details[:price],
        'Вес' => pl_details[:weight],
        'Размеры' => pl_details[:dimensions],
        'Коллекция' => pl_details[:collection]
      }
      
      # Атрибуты из модальных окон
      if modals_found.any?
        modals_found.each do |modal|
          # Парсим HTML модального окна
          doc = Nokogiri::HTML(modal[:html])
          
          # Ищем различные секции
          sections = {
            'Описание' => doc.css('p.pipf-product-details-modal__paragraph').map(&:text).join("\n"),
            'Материалы' => doc.css('dl dt, dl dd').map(&:text).join("\n"),
            'Дизайнер' => doc.css('[class*="designer"], [id*="designer"]').map(&:text).join("\n"),
            'Инструкции по уходу' => doc.css('[class*="care"], [id*="care"]').map(&:text).join("\n"),
            'Безопасность' => doc.css('[class*="safety"], [id*="safety"]').map(&:text).join("\n"),
            'Полезно знать' => doc.css('[class*="good"], [id*="good"]').map(&:text).join("\n")
          }
          
          sections.each do |key, value|
            if value.present?
              all_attributes[key] ||= []
              all_attributes[key] << value.strip
            end
          end
        end
      end
      
      puts "Найденные атрибуты:"
      all_attributes.each do |category, attrs|
        puts ""
        puts "  #{category}:"
        if attrs.is_a?(Hash)
          attrs.each do |key, value|
            puts "    - #{key}: #{value.present? ? 'Есть' : 'Нет'}"
          end
        elsif attrs.is_a?(Array)
          attrs.each_with_index do |value, idx|
            puts "    - Вариант #{idx + 1}: #{value[0..200]}..."
          end
        end
      end
      
      puts ""
      puts "=" * 80
      puts "ОТЛАДКА ЗАВЕРШЕНА"
      puts "=" * 80
      puts ""
      puts "Полные HTML модальных окон сохранены в log/development.log"
    rescue => e
      puts "ОШИБКА: #{e.class} - #{e.message}"
      puts e.backtrace.first(10).join("\n")
    end
  end
end

