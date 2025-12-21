require 'rails_helper'

RSpec.describe TelegramService do
  describe '.send_message' do
    before do
      allow(ENV).to receive(:[]).with('TELEGRAM_BOT_TOKEN').and_return('test_token')
      allow(ENV).to receive(:[]).with('TELEGRAM_CHAT_ID').and_return('123456')
    end

    it 'sends message via HTTP' do
      uri = URI('https://api.telegram.org/bot/test_token/sendMessage')
      allow(URI).to receive(:parse).and_return(uri)
      allow(Net::HTTP).to receive(:post_form).and_return(double(is_a?: true, body: '{"ok":true}'))
      
      TelegramService.send_message('Test message')
      
      expect(Net::HTTP).to have_received(:post_form)
    end

    it 'does not send if bot_token is missing' do
      allow(ENV).to receive(:[]).with('TELEGRAM_BOT_TOKEN').and_return(nil)
      
      expect(Net::HTTP).not_to receive(:post_form)
      TelegramService.send_message('Test message')
    end

    it 'does not send if chat_id is missing' do
      allow(ENV).to receive(:[]).with('TELEGRAM_BOT_TOKEN').and_return('test_token')
      allow(ENV).to receive(:[]).with('TELEGRAM_CHAT_ID').and_return(nil)
      
      expect(Net::HTTP).not_to receive(:post_form)
      TelegramService.send_message('Test message')
    end

    it 'handles errors gracefully' do
      uri = URI('https://api.telegram.org/bot/test_token/sendMessage')
      allow(URI).to receive(:parse).and_return(uri)
      allow(Net::HTTP).to receive(:post_form).and_raise(StandardError.new('Network error'))
      allow(Rails.logger).to receive(:error)
      
      TelegramService.send_message('Test message')
      
      expect(Rails.logger).to have_received(:error).with(/Telegram error/)
    end
  end

  describe '.send_parser_started' do
    it 'sends formatted message' do
      allow(TelegramService).to receive(:send_message)
      
      TelegramService.send_parser_started('categories', limit: 100)
      
      expect(TelegramService).to have_received(:send_message).once
    end
  end

  describe '.send_parser_completed' do
    it 'sends formatted message with stats' do
      allow(TelegramService).to receive(:send_message)
      
      stats = { processed: 100, created: 50, updated: 30, errors: 5, duration: 3600 }
      TelegramService.send_parser_completed('products', stats)
      
      expect(TelegramService).to have_received(:send_message).once
    end
  end

  describe '.send_parser_error' do
    it 'sends formatted error message' do
      allow(TelegramService).to receive(:send_message)
      
      error = StandardError.new('Test error')
      TelegramService.send_parser_error('categories', error)
      
      expect(TelegramService).to have_received(:send_message).once
    end
  end
end

