# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Создание дефолтного системного администратора
admin_username = 'admin'
admin_password = ENV['ADMIN_PASSWORD'] || 'admin123'
admin_email = ENV['ADMIN_EMAIL'] || 'admin@ikea_api.local'

admin = User.find_or_initialize_by(username: admin_username)
admin.assign_attributes(
  email: admin_email,
  password: admin_password,
  password_confirmation: admin_password,
  role: 'admin',
  is_active: true
)

if admin.save
  puts "✅ Системный администратор создан/обновлен:"
  puts "   Username: #{admin.username}"
  puts "   Email: #{admin.email}"
  puts "   Role: #{admin.role}"
  puts ""
  puts "⚠️  ВНИМАНИЕ: Измените пароль по умолчанию в production!"
  puts "   Для изменения пароля используйте переменную окружения ADMIN_PASSWORD"
else
  puts "❌ Ошибка при создании администратора:"
  admin.errors.full_messages.each do |message|
    puts "   - #{message}"
  end
end
