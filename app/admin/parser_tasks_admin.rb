# Админ-панель для управления задачами парсинга
Trestle.resource :parser_tasks, model: ParserTask do
  menu do
    item :parser_tasks, icon: "fa fa-tasks", label: "Задачи парсинга"
  end

  # Таблица
  table do
    column :id
    column :task_type, header: "Тип задачи" do |task|
      task_type_label(task.task_type)
    end
    column :status, header: "Статус" do |task|
      status_badge(task.status)
    end
    column :limit, header: "Лимит"
    column :processed, header: "Обработано"
    column :created, header: "Создано"
    column :updated, header: "Обновлено"
    column :errors, header: "Ошибок"
    column :started_at, header: "Начало"
    column :completed_at, header: "Завершено"
    column :created_at, header: "Создано", align: :center
    actions
  end

  # Форма
  form do |task|
    row do
      col(sm: 6) { text_field :task_type }
      col(sm: 6) { select :status, ParserTask::STATUSES }
    end
    
    row do
      col(sm: 4) { number_field :limit }
      col(sm: 4) { number_field :processed }
      col(sm: 4) { number_field :errors }
    end
    
    row do
      col(sm: 6) { datetime_field :started_at }
      col(sm: 6) { datetime_field :completed_at }
    end
    
    text_area :error_message
  end

  # Действия
  controller do
    def create
      # Создание задачи через админку запускает парсинг
      task = ParserTask.new(parser_task_params)
      
      if task.save
        # Запускаем соответствующую задачу
        job_class = job_class_for_task_type(task.task_type)
        job_class.perform_later(limit: task.limit)
        
        flash[:message] = "Задача парсинга запущена"
        redirect_to admin.collection_path
      else
        flash[:error] = "Ошибка создания задачи: #{task.errors.full_messages.join(', ')}"
        render :new
      end
    end

    def stop
      task = admin.find_instance(params)
      # Останавливаем задачу (устанавливаем статус)
      task.update(status: 'failed', error_message: 'Остановлено вручную')
      
      flash[:message] = "Задача остановлена"
      redirect_to admin.collection_path
    end

    private

    def parser_task_params
      params.require(:parser_task).permit(:task_type, :limit, :status)
    end

    def job_class_for_task_type(task_type)
      case task_type
      when 'categories'
        ParseCategoriesJob
      when 'products'
        ParseProductsJob
      when 'bestsellers'
        ParseBestsellersJob
      when 'popular_categories'
        ParsePopularCategoriesJob
      when 'category_images'
        DownloadCategoryImagesJob
      when 'product_images'
        DownloadProductImagesJob
      end
    end
  end

  routes do
    post :stop, on: :member
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

  def status_badge(status)
    color = {
      'pending' => 'secondary',
      'running' => 'primary',
      'completed' => 'success',
      'failed' => 'danger'
    }[status] || 'secondary'
    
    content_tag(:span, status, class: "badge badge-#{color}")
  end
end

