require "ferrum"
require "tmpdir"
require "fileutils"
require "json"
require "securerandom"

# Ensure we use project tmp dir for Snap compatibility
extension_dir = File.join(Dir.pwd, "tmp", "test-extension-#{SecureRandom.hex(4)}")
FileUtils.mkdir_p(extension_dir)

puts "Creating extension at: #{extension_dir}"

manifest = {
  "version" => "1.0.0",
  "manifest_version" => 2,
  "name" => "Test Extension",
  "permissions" => ["proxy", "tabs", "<all_urls>", "webRequest", "webRequestBlocking"],
  "background" => { "scripts" => ["background.js"] },
  "minimum_chrome_version" => "22.0.0"
}

background_js = <<~JS
  console.log('Background script running!');
  chrome.webRequest.onBeforeRequest.addListener(
    function(details) { console.log('Request:', details.url); },
    {urls: ["<all_urls>"]}
  );
JS

File.write(File.join(extension_dir, "manifest.json"), JSON.pretty_generate(manifest))
File.write(File.join(extension_dir, "background.js"), background_js)

browser_options = {
  "no-sandbox" => nil,
  "disable-gpu" => nil,
  "disable-extensions" => nil
}

browser_options.delete("disable-extensions")
browser_options["load-extension"] = extension_dir
browser_options["disable-extensions-except"] = extension_dir

begin
  puts "Attempt: headless=new with project tmp dir"
  browser = Ferrum::Browser.new(
    headless: false,
    browser_options: browser_options.merge("headless" => "new"),
    browser_path: ENV["CHROME_PATH"],
    timeout: 20
  )

  browser.go_to("about:blank")
  targets = browser.targets.values
  puts "Targets: #{targets.map(&:type).join(', ')}"
  
  if targets.any? { |t| t.type == "background_page" }
    puts "SUCCESS: Extension loaded!"
  else
    puts "FAILURE: Extension not loaded."
  end
  
rescue => e
  puts "Error: #{e.message}"
ensure
  browser&.quit
  FileUtils.rm_rf(extension_dir) if extension_dir && File.exist?(extension_dir)
end
