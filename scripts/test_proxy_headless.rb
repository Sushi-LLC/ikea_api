require "ferrum"

b = Ferrum::Browser.new(
  headless: true,
  browser_path: ENV["CHROME_PATH"],
  browser_options: {
    "no-sandbox" => nil,
    "disable-dev-shm-usage" => nil,
    "window-size" => "1366,768"
  }
)

b.go_to("https://example.com")
puts b.title
b.quit
