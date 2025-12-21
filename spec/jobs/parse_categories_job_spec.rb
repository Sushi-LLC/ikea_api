require 'rails_helper'

RSpec.describe ParseCategoriesJob, type: :job do
  include ActiveJob::TestHelper

  let(:categories_data) do
    [
      {
        'id' => '10412',
        'name' => 'Test Category',
        'url' => '/test',
        'children' => [
          {
            'id' => '10413',
            'name' => 'Subcategory',
            'url' => '/test/sub'
          }
        ]
      }
    ]
  end

  before do
    allow(IkeaApiService).to receive(:fetch_categories).and_return(categories_data)
    allow(TelegramService).to receive(:send_parser_started)
    allow(TelegramService).to receive(:send_parser_completed)
    allow(TelegramService).to receive(:send_parser_error)
  end

  describe '#perform' do
    it 'creates parser task' do
      expect {
        ParseCategoriesJob.perform_now(limit: 10)
      }.to change(ParserTask, :count).by(1)
    end

    it 'marks task as running' do
      ParseCategoriesJob.perform_now(limit: 10)
      task = ParserTask.last
      
      expect(task.status).to eq('completed')
      expect(task.started_at).to be_present
    end

    it 'sends telegram notification on start' do
      ParseCategoriesJob.perform_now(limit: 10)
      
      expect(TelegramService).to have_received(:send_parser_started).with('categories', limit: 10)
    end

    it 'sends telegram notification on completion' do
      ParseCategoriesJob.perform_now(limit: 10)
      
      expect(TelegramService).to have_received(:send_parser_completed).with('categories', hash_including(:processed, :created, :updated, :errors, :duration))
    end

    it 'creates categories from API data' do
      expect {
        ParseCategoriesJob.perform_now(limit: 10)
      }.to change(Category, :count).by(2) # Main category + subcategory
    end

    it 'updates existing categories' do
      category = create(:category, ikea_id: '10412', name: 'Old Name')
      
      ParseCategoriesJob.perform_now(limit: 10)
      
      expect(category.reload.name).to eq('Test Category')
    end

    it 'handles errors gracefully' do
      allow(IkeaApiService).to receive(:fetch_categories).and_raise(StandardError.new('API Error'))
      
      expect {
        ParseCategoriesJob.perform_now(limit: 10)
      }.not_to raise_error
      
      task = ParserTask.last
      expect(task.status).to eq('failed')
      expect(TelegramService).to have_received(:send_parser_error)
    end

    it 'respects limit parameter' do
      large_data = (1..100).map { |i| { 'id' => i.to_s, 'name' => "Category #{i}" } }
      allow(IkeaApiService).to receive(:fetch_categories).and_return(large_data)
      
      ParseCategoriesJob.perform_now(limit: 10)
      
      task = ParserTask.last
      expect(task.processed).to be <= 10
    end
  end
end

