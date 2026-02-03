require 'ferrum'
require 'fileutils'
require 'uri'

def test_ikea_with_proxy(proxy_url)
  puts "Testing IKEA access with proxy: #{proxy_url}"
  
  uri = URI.parse(proxy_url)
  proxy_host = uri.host
  proxy_port = uri.port
  proxy_user = uri.user
  proxy_pass = uri.password

  browser_options = {
    headless: true,
    process_timeout: 120,
    timeout: 120,
    browser_options: {
      'no-sandbox': nil,
      'disable-setuid-sandbox': nil,
      'proxy-server': "#{proxy_host}:#{proxy_port}"
    }
  }

  browser = Ferrum::Browser.new(browser_options)
  
  begin
    if proxy_user && proxy_pass
      puts "Setting proxy credentials via network.authorize with block..."
      browser.network.authorize(user: proxy_user, password: proxy_pass) { |r| r.continue }
    end

    url = 'https://www.ikea.com/pl/pl/p/skoenabaeck-sofa-2-osobowa-rozkladana-knisa-ciemnoszary-70582542/'
    puts "Navigating to #{url}..."
    
    begin
      browser.goto(url)
    rescue Ferrum::PendingConnectionsError
      puts "Warning: Pending connections error, but continuing..."
    rescue Ferrum::TimeoutError
      puts "Warning: Timeout error, but continuing to check body..."
    rescue => e
      puts "Warning: Navigation error: #{e.message}"
    end
    
    sleep 20
    
    puts "Page title: #{browser.title rescue 'N/A'}"
    
    body_content = browser.body rescue ""
    if body_content.include?("blocked") || body_content.include?("Access Denied")
      puts "FAILED: Access Denied / Blocked"
      puts "Body snippet: #{body_content.slice(0, 500)}"
    elsif body_content.length < 1000
      puts "FAILED: Page content too short (#{body_content.length} chars)"
      puts "Body length: #{body_content.length}"
    else
      puts "SUCCESS: Page loaded (length: #{body_content.length})"
      
      materials_text = browser.at_xpath("//*[contains(text(), 'Materiały')]")&.text
      puts "Materials text found: #{materials_text.inspect}" if materials_text
      
      browser.screenshot(path: "ikea_proxy_test.png")
      puts "Screenshot saved to ikea_proxy_test.png"
      
      File.write("ikea_proxy_test.html", body_content)
      puts "HTML saved to ikea_proxy_test.html"
    end

  rescue => e
    puts "ERROR: #{e.class} - #{e.message}"
    puts e.backtrace.first(5).join("\n")
  ensure
    browser.quit rescue nil
  end
end

proxy = "http://nSTqKwmf:tNmrExjK@172.121.67.114:64988"
test_ikea_with_proxy(proxy)
