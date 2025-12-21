require 'rails_helper'

RSpec.describe ParseProductsJob, type: :job do
  include ActiveJob::TestHelper

  let(:category) { create(:category, ikea_id: '10412') }
  let(:products_data) do
    [
      {
        'id' => '403.411.01',
        'typeName' => 'Test Product',
        'itemNo' => '40341101',
        'pipUrl' => '/pl/pl/p/test',
        'salesPrice' => { 'numeral' => 99.99 },
        'homeDelivery' => 'available'
      }
    ]
  end

  before do
    allow(Category).to receive_message_chain(:not_deleted, :find_each).and_yield(category)
    allow(IkeaApiService).to receive(:search_products_by_category).and_return(products_data)
    allow(TelegramService).to receive(:send_parser_started)
    allow(TelegramService).to receive(:send_parser_completed)
    allow(TelegramService).to receive(:send_parser_error)
  end

  describe '#perform' do
    it 'creates parser task' do
      expect {
        ParseProductsJob.perform_now(limit: 10)
      }.to change(ParserTask, :count).by(1)
    end

    it 'creates products from API data' do
      expect {
        ParseProductsJob.perform_now(limit: 10)
      }.to change(Product, :count).by(1)
      
      product = Product.last
      expect(product.sku).to eq('403.411.01')
      expect(product.name).to eq('Test Product')
      expect(product.category_id).to eq(category.ikea_id)
    end

    it 'updates existing products' do
      product = create(:product, sku: '403.411.01', name: 'Old Name')
      
      ParseProductsJob.perform_now(limit: 10)
      
      expect(product.reload.name).to eq('Test Product')
    end

    it 'sends telegram notifications' do
      ParseProductsJob.perform_now(limit: 10)
      
      expect(TelegramService).to have_received(:send_parser_started).with('products', limit: 10)
      expect(TelegramService).to have_received(:send_parser_completed)
    end

    it 'handles errors gracefully' do
      # Выбрасываем ошибку в основном блоке begin/rescue
      allow(Category).to receive(:not_deleted).and_raise(StandardError.new('API Error'))
      
      expect {
        ParseProductsJob.perform_now(limit: 10)
      }.not_to raise_error
      
      task = ParserTask.last
      expect(task.status).to eq('failed')
      expect(TelegramService).to have_received(:send_parser_error)
    end

    it 'respects limit parameter' do
      large_data = (1..100).map do |i|
        {
          'id' => "403.411.0#{i}",
          'typeName' => "Product #{i}",
          'itemNo' => "4034110#{i}",
          'pipUrl' => '/pl/pl/p/test',
          'salesPrice' => { 'numeral' => 99.99 }
        }
      end
      allow(IkeaApiService).to receive(:search_products_by_category).and_return(large_data)
      
      ParseProductsJob.perform_now(limit: 10)
      
      task = ParserTask.last
      expect(task.processed).to be <= 10
    end
  end
end

