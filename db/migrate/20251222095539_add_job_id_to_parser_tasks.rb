class AddJobIdToParserTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :parser_tasks, :job_id, :string
    add_index :parser_tasks, :job_id
  end
end
