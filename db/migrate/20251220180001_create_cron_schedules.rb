class CreateCronSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :cron_schedules do |t|
      t.string :task_type, null: false
      t.string :schedule, null: false # Cron expression
      t.boolean :enabled, default: true
      t.datetime :last_run_at
      t.datetime :next_run_at

      t.timestamps
    end
    
    add_index :cron_schedules, :task_type, unique: true
    add_index :cron_schedules, :enabled
    add_index :cron_schedules, :next_run_at
  end
end


