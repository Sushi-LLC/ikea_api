require 'rails_helper'

RSpec.describe ParserTask, type: :model do
  describe 'validations' do
    subject { build(:parser_task) }
    
    it 'validates presence of task_type' do
      subject.task_type = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:task_type]).to be_present
    end
    
    it 'validates presence of status' do
      subject.status = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:status]).to be_present
    end
    
    it 'validates inclusion of task_type' do
      subject.task_type = 'invalid'
      expect(subject).not_to be_valid
      expect(subject.errors[:task_type]).to be_present
    end
    
    it 'validates inclusion of status' do
      subject.status = 'invalid'
      expect(subject).not_to be_valid
      expect(subject.errors[:status]).to be_present
    end
  end

  describe 'scopes' do
    let!(:running_task) { create(:parser_task, status: 'running') }
    let!(:completed_task) { create(:parser_task, status: 'completed') }
    let!(:failed_task) { create(:parser_task, status: 'failed') }

    it 'returns running tasks' do
      expect(ParserTask.running).to include(running_task)
      expect(ParserTask.running).not_to include(completed_task, failed_task)
    end

    it 'returns completed tasks' do
      expect(ParserTask.completed).to include(completed_task)
      expect(ParserTask.completed).not_to include(running_task, failed_task)
    end

    it 'returns failed tasks' do
      expect(ParserTask.failed).to include(failed_task)
      expect(ParserTask.failed).not_to include(running_task, completed_task)
    end

    it 'returns recent tasks ordered by created_at desc' do
      # Используем travel_to для явного контроля времени
      old_task = nil
      new_task = nil
      
      travel_to 2.days.ago do
        old_task = create(:parser_task)
      end
      
      travel_to 1.hour.ago do
        new_task = create(:parser_task)
      end
      
      # Обновляем время для корректного сравнения
      old_task = ParserTask.order(created_at: :asc).first
      new_task = ParserTask.order(created_at: :desc).first
      
      expect(ParserTask.recent.first).to eq(new_task)
      expect(ParserTask.recent).to include(old_task)
    end

    it 'filters by task type' do
      categories_task = create(:parser_task, task_type: 'categories')
      products_task = create(:parser_task, task_type: 'products')
      
      expect(ParserTask.by_type('categories')).to include(categories_task)
      expect(ParserTask.by_type('categories')).not_to include(products_task)
    end
  end

  describe '#duration' do
    it 'returns nil if task not started' do
      task = build(:parser_task, started_at: nil, completed_at: nil)
      expect(task.duration).to be_nil
    end

    it 'returns nil if task not completed' do
      task = build(:parser_task, started_at: 1.hour.ago, completed_at: nil)
      expect(task.duration).to be_nil
    end

    it 'returns duration in seconds' do
      started_at = 1.hour.ago
      completed_at = Time.current
      task = build(:parser_task, started_at: started_at, completed_at: completed_at)
      
      expect(task.duration).to be_within(1).of(3600)
    end
  end

  describe '#mark_as_running!' do
    it 'sets status to running and started_at' do
      task = create(:parser_task, status: 'pending', started_at: nil)
      
      task.mark_as_running!
      
      expect(task.status).to eq('running')
      expect(task.started_at).to be_present
      expect(task.error_message).to be_nil
    end
  end

  describe '#mark_as_completed!' do
    it 'sets status to completed with stats' do
      task = create(:parser_task, status: 'running')
      
      task.mark_as_completed!(processed: 100, created: 50, updated: 30, errors: 5)
      
      expect(task.status).to eq('completed')
      expect(task.completed_at).to be_present
      expect(task.processed).to eq(100)
      expect(task.created).to eq(50)
      expect(task.updated).to eq(30)
      expect(task.error_count).to eq(5)
    end
  end

  describe '#mark_as_failed!' do
    it 'sets status to failed with error message' do
      task = create(:parser_task, status: 'running')
      
      task.mark_as_failed!('Test error')
      
      expect(task.status).to eq('failed')
      expect(task.completed_at).to be_present
      expect(task.error_message).to eq('Test error')
    end
  end

  describe 'increment methods' do
    let(:task) { create(:parser_task, processed: 0, created: 0, updated: 0, error_count: 0) }

    it 'increments processed' do
      expect { task.increment_processed! }.to change { task.reload.processed }.by(1)
    end

    it 'increments created' do
      expect { task.increment_created! }.to change { task.reload.created }.by(1)
    end

    it 'increments updated' do
      expect { task.increment_updated! }.to change { task.reload.updated }.by(1)
    end

    it 'increments errors' do
      expect { task.increment_errors! }.to change { task.reload.error_count }.by(1)
    end
  end
end

