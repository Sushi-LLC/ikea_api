# scripts/verify_tracking.rb
require_relative '../config/environment'

puts "Starting Tracking verification..."

user = User.first || User.create!(username: "test_user", phone: "79991234567", password: "password")
order = Order.create!(
  user: user,
  status: :created,
  total_amount: 200.0,
  delivery_type: 'europost',
  track_number: 'EP123456789',
  full_name: 'Test Testov',
  phone: '79991234567'
)

puts "\nTesting Europost Tracking:"
tracking = DeliveryTrackingService.call(order)
puts tracking.inspect

if tracking[:provider] == 'Европочта' && tracking[:tracking_url].include?('EP123456789')
  puts "SUCCESS: Europost tracking info correct."
else
  puts "FAILURE: Europost tracking info mismatch."
end

order.update!(delivery_type: 'autolight', track_number: 'AL987654321')
puts "\nTesting Autolight Tracking:"
tracking = DeliveryTrackingService.call(order)
puts tracking.inspect

if tracking[:provider] == 'Автолайт' && tracking[:tracking_url].include?('AL987654321')
  puts "SUCCESS: Autolight tracking info correct."
else
  puts "FAILURE: Autolight tracking info mismatch."
end

puts "\nTesting Serializer Output:"
json = OrderSerializer.new(order).serializable_hash.to_json
puts json

if json.include?('tracking_info') && json.include?('AL987654321')
  puts "SUCCESS: Serializer includes tracking info."
else
  puts "FAILURE: Serializer missing tracking info."
end

puts "\nVerification complete."
order.destroy # Cleanup
