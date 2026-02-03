namespace :products do
  desc "Debug PlDetailsFetcher on a single product (direct + scrape.do fallback)"
  task :test_fetch, [:url] => :environment do |_, args|
    url = args[:url] || 'https://www.ikea.com/pl/pl/p/skoenabaeck-sofa-2-osobowa-rozkladana-knisa-ciemnoszary-70582542/'

    puts "URL: #{url}"
    puts "SCRAPE_DO_API_TOKEN set: #{ENV['SCRAPE_DO_API_TOKEN'].present?}"
    puts "Using headless: #{ENV.fetch('USE_HEADLESS', 'true')}"

    data = PlDetailsFetcher.fetch(url, use_headless: ENV.fetch('USE_HEADLESS', 'true') == 'true')

    puts "\n== Basic =="
    puts "name: #{data[:name].inspect}"
    puts "sku: #{data[:sku].inspect}"
    puts "collection: #{data[:collection].inspect}"
    puts "price: #{data[:price].inspect}"
    puts "dimensions: #{data[:dimensions].inspect}"
    puts "weight: #{data[:weight].inspect}"

    puts "\n== Product info =="
    puts "short_description: #{data[:short_description]&.slice(0, 160).inspect}"
    puts "description (len): #{data[:description].to_s.length}"

    puts "\n== Extended =="
    puts "materials (len): #{data[:materials].to_s.length}"
    puts "care_instructions (len): #{data[:care_instructions].to_s.length}"
    puts "safety_info (len): #{data[:safety_info].to_s.length}"
    puts "good_to_know (len): #{data[:good_to_know].to_s.length}"

    puts "\n== Documents =="
    if data[:assembly_documents].is_a?(Array)
      puts "assembly_documents: #{data[:assembly_documents].length}"
      data[:assembly_documents].each do |d|
        puts "- #{d[:title]}: #{d[:url]}"
      end
    else
      puts "assembly_documents: #{data[:assembly_documents].inspect}"
    end
  end
end
