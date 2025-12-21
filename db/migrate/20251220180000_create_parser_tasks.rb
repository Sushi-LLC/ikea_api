class CreateParserTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :parser_tasks do |t|
      t.string :task_type, null: false, index: true
      t.string :status, default: 'pending', index: true
      t.integer :limit
      t.integer :processed, default: 0
      t.integer :created, default: 0
      t.integer :updated, default: 0
      t.integer :errors, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end
    
    add_index :parser_tasks, [:task_type, :status]
    add_index :parser_tasks, :created_at
  end
end


