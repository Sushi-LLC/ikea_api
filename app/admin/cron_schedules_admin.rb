# Админ-панель для управления cron расписаниями
Trestle.resource :cron_schedules, model: CronSchedule do
  menu do
    item :cron_schedules, icon: "fa fa-clock", label: "Cron расписания"
  end

  # Таблица
  table do
    column :task_type, header: "Тип задачи" do |schedule|
      task_type_label(schedule.task_type)
    end
    column :schedule, header: "Расписание"
    column :enabled, header: "Включено" do |schedule|
      enabled_badge(schedule.enabled?)
    end
    column :last_run_at, header: "Последний запуск"
    column :next_run_at, header: "Следующий запуск"
    column :created_at, header: "Создано"
    actions
  end

  # Форма
  form do |schedule|
    row do
      col(sm: 6) do
        select :task_type, CronSchedule::TASK_TYPES.map { |t| [task_type_label(t), t] }
      end
      col(sm: 6) { check_box :enabled }
    end
    
    text_field :schedule, placeholder: "0 2 * * * (каждый день в 2:00)", 
               help: "Cron выражение. Примеры: '0 2 * * *' (каждый день в 2:00), '0 */6 * * *' (каждые 6 часов)"
    
    row do
      col(sm: 6) { datetime_field :last_run_at, readonly: true }
      col(sm: 6) { datetime_field :next_run_at, readonly: true }
    end
  end

  # Действия
  controller do
    def create
      schedule = CronSchedule.new(cron_schedule_params)
      
      if schedule.save
        CronManagerService.setup_cron_schedule(schedule) if schedule.enabled?
        flash[:message] = "Cron расписание создано"
        redirect_to admin.instance_path(schedule)
      else
        flash[:error] = "Ошибка: #{schedule.errors.full_messages.join(', ')}"
        render :new
      end
    end

    def update
      schedule = admin.find_instance(params)
      
      if schedule.update(cron_schedule_params)
        if schedule.enabled?
          CronManagerService.setup_cron_schedule(schedule)
        else
          CronManagerService.remove_cron_schedule(schedule)
        end
        flash[:message] = "Cron расписание обновлено"
        redirect_to admin.instance_path(schedule)
      else
        flash[:error] = "Ошибка: #{schedule.errors.full_messages.join(', ')}"
        render :edit
      end
    end

    def sync
      begin
        CronManagerService.sync_all_schedules
        flash[:message] = "Все cron расписания синхронизированы"
      rescue => e
        flash[:error] = "Ошибка синхронизации: #{e.message}"
      end
      redirect_to admin.collection_path
    end

    private

    def cron_schedule_params
      params.require(:cron_schedule).permit(:task_type, :schedule, :enabled)
    end
  end

  routes do
    post :sync, on: :collection
  end

  # Вспомогательные методы
  def task_type_label(type)
    {
      'categories' => 'Категории',
      'products' => 'Продукты',
      'bestsellers' => 'Хиты продаж',
      'popular_categories' => 'Популярные категории',
      'category_images' => 'Картинки категорий',
      'product_images' => 'Картинки продуктов'
    }[type] || type
  end

  def enabled_badge(enabled)
    color = enabled ? 'success' : 'secondary'
    text = enabled ? 'Да' : 'Нет'
    content_tag(:span, text, class: "badge badge-#{color}")
  end
end

