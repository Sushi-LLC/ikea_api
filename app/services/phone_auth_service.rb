class PhoneAuthService
  def self.send_code(phone:)
    return { error: 'Неверный формат телефона' } if phone.blank? # простая валидация пока

    # Удаляем старые коды
    VerificationCode.where(phone: phone).destroy_all

    code = VerificationCode.generate_code
    VerificationCode.create!(
      phone: phone, 
      code: code, 
      expires_at: 10.minutes.from_now
    )

    SmsSenderService.send(phone, code)
    { success: true, message: 'Код отправлен' }
  end

  def self.verify_code(phone:, code:)
    verification = VerificationCode.valid_code(phone, code).first
    
    return { error: 'Неверный или просроченный код' } unless verification

    verification.destroy!

    user = User.find_or_initialize_by(phone: phone)
    
    is_new_user = user.new_record?
    
    if is_new_user
      # Генерируем рандомный пароль, так как валидация password выключена для phone auth,
      # но has_secure_password требует его наличия внутри себя для дайджеста.
      # Либо мы обошли валидацию, но password_digest нужен для модели? 
      # has_secure_password создает password= метод.
      
      # Используем номер телефона как username, если он уникален
      user.username = phone
      user.password = SecureRandom.hex(12)
      user.role = 'user'
      
      unless user.save
        return { error: user.errors.full_messages.join(', ') }
      end
    end

    { success: true, user: user, is_new: is_new_user }
  end
end
