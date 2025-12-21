require 'rails_helper'

RSpec.describe ProxyRotator do
  describe '.get_proxy' do
    context 'when proxies are configured' do
      before do
        stub_const('ProxyRotator::PROXY_LIST', ['http://user:pass@proxy1:8080', 'http://user:pass@proxy2:8080'])
      end

      it 'returns proxy from list' do
        proxy = ProxyRotator.get_proxy
        expect(proxy).to be_present
        expect(proxy).to match(/proxy/)
      end

      it 'rotates proxies round-robin' do
        proxy1 = ProxyRotator.get_proxy
        proxy2 = ProxyRotator.get_proxy
        proxy3 = ProxyRotator.get_proxy
        
        expect(proxy1).to eq(proxy3) # Round-robin returns to first
        expect(proxy2).not_to eq(proxy1)
      end
    end

    context 'when no proxies configured' do
      before do
        stub_const('ProxyRotator::PROXY_LIST', [])
      end

      it 'returns nil' do
        expect(ProxyRotator.get_proxy).to be_nil
      end
    end
  end

  describe '.with_proxy_retry' do
    context 'when proxies are configured' do
      before do
        stub_const('ProxyRotator::PROXY_LIST', ['http://user:pass@proxy1:8080'])
      end

      it 'yields proxy options' do
        ProxyRotator.with_proxy_retry do |proxy_options|
          expect(proxy_options).to be_a(Hash)
          expect(proxy_options[:http_proxyaddr]).to be_present
          expect(proxy_options[:http_proxyport]).to be_present
        end
      end

      it 'retries with next proxy on 403 error' do
        stub_const('ProxyRotator::PROXY_LIST', ['http://user:pass@proxy1:8080', 'http://user:pass@proxy2:8080'])
        
        call_count = 0
        ProxyRotator.with_proxy_retry do |proxy_options|
          call_count += 1
          raise StandardError.new('403') if call_count == 1
          'success'
        end
        
        expect(call_count).to eq(2)
      end
    end

    context 'when no proxies configured' do
      before do
        stub_const('ProxyRotator::PROXY_LIST', [])
      end

      it 'works without proxies' do
        result = ProxyRotator.with_proxy_retry do |proxy_options|
          expect(proxy_options).to be_nil
          'success'
        end
        
        expect(result).to eq('success')
      end
    end
  end
end

