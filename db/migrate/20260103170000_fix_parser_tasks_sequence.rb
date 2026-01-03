class FixParserTasksSequence < ActiveRecord::Migration[7.1]
  def up
    # Исправляем последовательность, если она не синхронизирована
    # Получаем максимальный ID
    max_id_result = execute("SELECT COALESCE(MAX(id), 0) as max_id FROM parser_tasks").first
    max_id = max_id_result['max_id'].to_i
    next_id = max_id + 1
    
    # Получаем имя последовательности для колонки id
    seq_name_result = execute("SELECT pg_get_serial_sequence('parser_tasks', 'id') as seq_name").first
    seq_name = seq_name_result['seq_name']
    
    if seq_name.present?
      # Исправляем последовательность
      execute("SELECT setval('#{seq_name}', #{next_id}, false)")
      Rails.logger.info "Fixed #{seq_name}: set to #{next_id}"
    else
      # Если последовательность не найдена, пробуем стандартное имя
      begin
        execute("SELECT setval('parser_tasks_id_seq', #{next_id}, false)")
        Rails.logger.info "Fixed parser_tasks_id_seq: set to #{next_id}"
      rescue => e
        Rails.logger.error "Could not fix sequence: #{e.message}"
        raise
      end
    end
  end
  
  def down
    # Откат не требуется, это исправление данных
  end
end

