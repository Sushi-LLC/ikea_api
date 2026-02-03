require "logger"
Rails.logger = Logger.new($stdout)
Rails.logger.level = Logger::DEBUG

url = "https://www.ikea.com/pl/pl/p/skoenabaeck-sofa-2-osobowa-rozkladana-knisa-ciemnoszary-70582542/"
fetcher = PlDetailsFetcher.new
modal = fetcher.send(:fetch_modal_with_headless_browser, url)

puts "modal keys: #{modal.keys.sort}"
puts "materials? #{!modal[:materials].to_s.strip.empty?}"
puts "care? #{!modal[:care_instructions].to_s.strip.empty?}"
puts "safety? #{!modal[:safety_info].to_s.strip.empty?}"
puts "good_to_know? #{!modal[:good_to_know].to_s.strip.empty?}"
