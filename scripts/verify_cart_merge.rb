
# scripts/verify_cart_merge.rb
require_relative '../config/environment'

puts "Starting verification..."

# 1. Create a guest cart and add an item
guest_token = SecureRandom.hex(24)
product = Product.first || Product.create!(name: "Test", price: 100, sku: "TEST-1")
guest_cart = Cart.create!(guest_token: guest_token, expires_at: 1.day.from_now)
CartItem.create!(cart: guest_cart, product: product, quantity: 1)

puts "Guest cart created with 1 item. Token: #{guest_token}"

# 2. Create a user
user = User.find_by(username: "merge_test") || User.create!(username: "merge_test", password: "password", role: "user")
user.cart&.destroy # Ensure clean slate

puts "User created: #{user.username}"

# 3. Simulate AuthController login behavior calling the service directly (to test service first)
puts "Merging carts..."
CartMergeService.call(guest_token: guest_token, user: user)

# 4. Verify result
user.reload
if user.cart.present? && user.cart.cart_items.count == 1
  puts "SUCCESS: User has a cart with 1 item."
  puts "User cart token: #{user.cart.guest_token}"
else
  puts "FAILURE: User cart missing or empty."
  exit 1
end

# 5. Verify guest cart is gone
if Cart.find_by(guest_token: guest_token).nil?
  puts "SUCCESS: Guest cart was deleted."
else
  puts "FAILURE: Guest cart still exists."
end

puts "Verification complete."
