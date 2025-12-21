# Админ-панель для быстрого управления парсером
Trestle.resource :parser_control, model: ParserControl do
  menu do
    item :parser_control, icon: "fa fa-play-circle", label: "Управление парсером", priority: :first
  end

  # Показываем только форму управления
  controller do
    def index
      redirect_to admin.instance_path(ParserControl.new(id: 'show'))
    end

    def show
      @running_tasks = ParserTask.running.recent.limit(10)
      @recent_tasks = ParserTask.recent.limit(20)
      render "trestle/parser_control/show"
    end

    def start_task
      task_type = params[:task_type]
      limit = params[:limit].present? ? params[:limit].to_i : nil
      
      begin
        job_class = job_class_for_task_type(task_type)
        job_class.perform_later(limit: limit)
        
        flash[:message] = "Задача '#{task_type_label(task_type)}' запущена"
      rescue => e
        flash[:error] = "Ошибка запуска задачи: #{e.message}"
      end
      
      redirect_to admin.instance_path(ParserControl.new(id: 'show'))
    end

    def stop_task
      task_id = params[:task_id]
      
      begin
        task = ParserTask.find(task_id)
        
        if task.status == 'running'
          task.update(status: 'failed', error_message: 'Остановлено вручную')
          flash[:message] = "Задача остановлена"
        else
          flash[:error] = "Задача не запущена"
        end
      rescue => e
        flash[:error] = "Ошибка остановки задачи: #{e.message}"
      end
      
      redirect_to admin.instance_path(ParserControl.new(id: 'show'))
    end

    private

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
  end

  routes do
    post :start_task, on: :collection
    post :stop_task, on: :collection
  end
end

