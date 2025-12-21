class RenameErrorsToErrorCountInParserTasks < ActiveRecord::Migration[7.1]
  def change
    rename_column :parser_tasks, :errors, :error_count
  end
end
