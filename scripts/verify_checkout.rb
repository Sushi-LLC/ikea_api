
# scripts/verify_checkout.rb
require_relative '../config/environment'

puts "Starting Checkout verification..."

# 1. Setup Data
phone = "79998887766"
user = User.find_by(phone: phone)
if user
  Cart.where(user: user).destroy_all
  Order.where(user: user).destroy_all
  user.destroy!
end

user = User.create!(username: "checkout_test", phone: phone, password: "password", role: "user")
product = Product.first
product.update!(price: 100, quantity: 10) if product
product ||= Product.create!(name: "Chair", price: 100, sku: "CHAIR-1", quantity: 10)

expensive_product = Product.where(sku: "SOFA-1").first_or_create!(name: "Sofa", price: 200, quantity: 5)
out_of_stock_product = Product.where(sku: "TABLE-1").first_or_create!(name: "Table", price: 500, quantity: 0)
# Ensure clean state
out_of_stock_product.update!(quantity: 0)

# 2. Test Min Order Sum < 150
puts "\nTest 1: Min Order Sum < 150"
cart = user.cart || user.create_cart!
cart.cart_items.destroy_all
# Force price 100
product.reload.update!(price: 100)
CartItem.create!(cart: cart, product: product, quantity: 1) # Total 100

# Inspect cart totals before call
pricing = CartPricingService.call(cart: cart)
puts "DEBUG: Cart total: #{pricing[:totals][:subtotal_new_byn]}"

# Reload user to avoid caching issues with cart association
result = CheckoutService.call(user: user.reload, params: {})
if result[:error] && result[:error].include?("доступно от 150")
  puts "SUCCESS: Blocked low value order."
else
  puts "FAILURE: Allowed low value order or wrong error: #{result.inspect}"
end

# 3. Test Out of Stock
puts "\nTest 2: Out of Stock"
cart.reload
cart.cart_items.destroy_all
CartItem.create!(cart: cart, product: out_of_stock_product, quantity: 1)

result = CheckoutService.call(user: user.reload, params: {})
if result[:error] && result[:error].include?("нет в наличии")
  puts "SUCCESS: Blocked out of stock order."
else
  puts "FAILURE: Allowed out of stock order: #{result.inspect}"
end

# 4. Test Successful Checkout
puts "\nTest 3: Successful Checkout"
cart.reload
cart.cart_items.destroy_all
CartItem.create!(cart: cart, product: expensive_product, quantity: 1) # Total 200 > 150

params = {
  full_name: "Ivan Ivanov",
  phone: "79998887766",
  delivery_type: "courier",
  payment_method: "card",
  address: { city: "Minsk", street: "Lenina 1" }
}

result = CheckoutService.call(user: user.reload, params: params)
if result[:success]
  order = result[:order]
  puts "SUCCESS: Order created (ID: #{order.id})."
  
  if order.total_amount == 200.0 && order.status == "created"
    puts "SUCCESS: Order totals correct."
  else
    puts "FAILURE: Order totals mismatch."
  end
  
  if user.cart.cart_items.empty?
    puts "SUCCESS: Cart cleared."
  else
    puts "FAILURE: Cart not cleared."
  end
  
  if OrderItem.where(order: order).count == 1
    puts "SUCCESS: Order items moved."
  else
    puts "FAILURE: Order items missing."
  end
else
  puts "FAILURE: Checkout failed: #{result[:error]}"
end

puts "\nVerification complete."
