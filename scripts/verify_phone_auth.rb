
# scripts/verify_phone_auth.rb
require_relative '../config/environment'

puts "Starting verification..."

phone = "79991234567"
puts "Testing for phone: #{phone}"

# 1. Clear previous data
User.where(phone: phone).destroy_all
VerificationCode.where(phone: phone).destroy_all

# 2. Test sending code
puts "Sending code..."
result = PhoneAuthService.send_code(phone: phone)
if result[:success]
  puts "SUCCESS: Code sent."
else
  puts "FAILURE: Send code failed: #{result[:error]}"
  exit 1
end

# 3. Retrieve the code (cheat to verify)
code_record = VerificationCode.where(phone: phone).last
unless code_record
  puts "FAILURE: Code not found in database."
  exit 1
end
code = code_record.code
puts "Code found in DB: #{code}"

# 4. Test verify code (Register & Login)
puts "Verifying code and registering..."

# Create a guest cart to test merge
guest_token = SecureRandom.hex(24)
Cart.create!(guest_token: guest_token, expires_at: 1.day.from_now)

# Mock Request Context (not easily doable in script without full controller test, 
# so we test service logic directly for user creation + mock token)

result = PhoneAuthService.verify_code(phone: phone, code: code)
if result[:success]
  puts "SUCCESS: Code verified."
  user = result[:user]
  if user.present? && user.phone == phone
    puts "SUCCESS: User created with phone #{user.phone}."
  else
    puts "FAILURE: User mismatch."
    exit 1
  end
  
  if result[:is_new]
    puts "SUCCESS: is_new flag is true."
  else
    puts "FAILURE: is_new flag is false."
  end
  
  # Manually test merge service since we called it in controller, but here we can check if it works for this user
  puts "Testing cart merge for this user..."
  CartMergeService.call(guest_token: guest_token, user: user)
  user.reload
  if user.cart.present?
     puts "SUCCESS: Cart merged."
  else
     puts "FAILURE: Cart not merged."
  end
  
else
  puts "FAILURE: Verification failed: #{result[:error]}"
  exit 1
end

puts "Verification complete."
