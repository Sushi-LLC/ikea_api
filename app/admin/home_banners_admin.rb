Trestle.resource(:home_banners, model: HomeBanner) do
  menu do
    item :home_banners, icon: "fa fa-images", priority: 3, label: "Слайдер главной", group: "Content"
  end

  scopes do
    scope :all, default: true
    scope :main, -> { HomeBanner.main }, label: "Основная информация"
    scope :secondary, -> { HomeBanner.secondary }, label: "Баннеры"
    scope :active, -> { HomeBanner.active }, label: "Активные"
  end

  table do
    column :id
    column :image, align: :center do |banner|
      if banner.image.attached?
        image_tag Rails.application.routes.url_helpers.rails_blob_path(banner.image, only_path: true), style: "max-width: 80px; max-height: 60px;"
      else
        content_tag :span, "Нет изображения", class: "text-muted"
      end
    end
    column :section do |banner|
      case banner.section
      when 'main'
        status_tag('Основная', :info)
      when 'secondary'
        status_tag('Баннеры', :success)
      else
        banner.section
      end
    end
    column :variant do |banner|
      case banner.variant
      when 'main_1500x516'
        '1500×516'
      when 'main_572x594'
        '572×594'
      when 'secondary_1500x256'
        '1500×256'
      when 'secondary_742x256'
        '742×256'
      else
        banner.variant
      end
    end
    column :title, link: true
    column :category do |banner|
      banner.category&.name || '—'
    end
    column :position, sortable: true
    column :active do |banner|
      status_tag(banner.active? ? 'Активен' : 'Неактивен', 
                 banner.active? ? :success : :danger)
    end
    column :created_at, align: :center
    actions do |actions|
      actions.show
      actions.edit
      actions.delete
    end
  end

  form do |banner|
    section_variants = {
      'main' => {
        '1500×516' => 'main_1500x516',
        '572×594' => 'main_572x594'
      },
      'secondary' => {
        '1500×256' => 'secondary_1500x256',
        '742×256' => 'secondary_742x256'
      }
    }

    row do
      col(sm: 6) do
        select :section, {
          'Основная информация' => 'main',
          'Баннеры' => 'secondary'
        }, label: "Секция", html: { id: "home_banner_section", data: { variants: section_variants.to_json } }
      end
      col(sm: 6) do
        current_section = banner.section.presence || (banner.persisted? ? banner.section : 'main')
        variant_options = section_variants[current_section] || section_variants['main']

        select :variant, variant_options, { include_blank: false }, label: "Вариант размера", html: { id: "home_banner_variant", data: { selected: banner.variant } }
      end
    end

    concat(content_tag(:script, type: "text/javascript") do
      raw <<-JS.strip_heredoc
        (function() {
          var sectionVariants = #{section_variants.to_json.html_safe};
          var sectionSelect = document.getElementById("home_banner_section");
          var variantSelect = document.getElementById("home_banner_variant");
          if (!sectionSelect || !variantSelect) { return; }

          function rebuildOptions() {
            var selectedSection = sectionSelect.value || Object.keys(sectionVariants)[0];
            var options = sectionVariants[selectedSection] || {};
            var prevValue = variantSelect.value || variantSelect.dataset.selected;
            variantSelect.innerHTML = "";

            Object.keys(options).forEach(function(label) {
              var value = options[label];
              var option = document.createElement("option");
              option.value = value;
              option.textContent = label;

              if (value === prevValue) {
                option.selected = true;
              }

              variantSelect.appendChild(option);
            });

            if (!variantSelect.value && variantSelect.options.length) {
              variantSelect.selectedIndex = 0;
            }
          }

          sectionSelect.addEventListener("change", function() {
            rebuildOptions();
          });

          function init() {
            rebuildOptions();
          }

          document.addEventListener("turbo:load", init);
          if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", init);
          } else {
            init();
          }
        })();
      JS
    end)

    row do
      col(sm: 6) do
        text_field :title, label: "Заголовок"
      end
      col(sm: 6) do
        text_field :subtitle, label: "Подзаголовок"
      end
    end

    row do
      col(sm: 12) do
        # Выпадающий список категорий (1 и 2 уровень)
        categories = Category.active.order(:name).map do |cat|
          name = cat.translated_name.presence || cat.name
          level_indicator = cat.is_important || (cat.parent_ids.blank? || (cat.parent_ids.is_a?(Array) && cat.parent_ids.empty?)) ? "★ " : "  "
          ["#{level_indicator}#{name}", cat.ikea_id]
        end
        select :category_id, categories, { include_blank: 'Выберите категорию...' }, label: "Категория"
      end
    end

    row do
      col(sm: 12) do
        concat(content_tag(:div, id: "image-preview-container", style: "margin-bottom: 15px;") do
          content = +""
          if banner.persisted? && banner.image.attached?
            content << content_tag(:div, class: "current-image-preview", style: "margin-bottom: 15px; padding: 10px; background: #f8f9fa; border-radius: 4px;") do
              image_tag(Rails.application.routes.url_helpers.rails_blob_path(banner.image, only_path: true),
                       style: "max-width: 400px; max-height: 300px; display: block; margin: 0 auto; border: 1px solid #ddd; border-radius: 4px;",
                       id: "current-image-preview") +
              content_tag(:p, "Текущее изображение", style: "text-align: center; margin-top: 10px; color: #666; font-size: 12px;")
            end
          end
          content << content_tag(:div, id: "new-image-preview", style: "display: none; margin-bottom: 15px; padding: 10px; background: #e8f5e9; border-radius: 4px;") do
            content_tag(:img, "", id: "image-preview", style: "max-width: 400px; max-height: 300px; display: block; margin: 0 auto; border: 1px solid #4caf50; border-radius: 4px;") +
            content_tag(:p, "Предпросмотр нового изображения", style: "text-align: center; margin-top: 10px; color: #2e7d32; font-size: 12px; font-weight: bold;")
          end
          content.html_safe
        end)

        file_field :image, label: "Изображение"
        content_tag :small, "Разрешены: WebP, AVIF, PNG, JPEG. Размер должен соответствовать выбранному варианту.", class: "text-muted"

        if banner.variant.present?
          expected = banner.expected_dimensions
          if expected
            content_tag :div, class: "alert alert-info", style: "margin-top: 10px;" do
              "Требуемый размер: #{expected[0]}×#{expected[1]} пикселей"
            end
          end
        end

        # JavaScript для предпросмотра изображения
        concat(content_tag(:script, type: "text/javascript") do
          raw <<-JS.strip_heredoc
            (function() {
              function initImagePreview() {
                var fileInput = document.querySelector('input[type="file"][name*="[image]"]');
                if (!fileInput) return;

                var preview = document.getElementById('image-preview');
                var container = document.getElementById('new-image-preview');
                var currentPreview = document.querySelector('.current-image-preview');

                fileInput.addEventListener('change', function(e) {
                  if (e.target.files && e.target.files[0]) {
                    var reader = new FileReader();

                    reader.onload = function(event) {
                      if (preview) preview.src = event.target.result;
                      if (container) container.style.display = 'block';
                      if (currentPreview) currentPreview.style.display = 'none';
                    };

                    reader.readAsDataURL(e.target.files[0]);
                  } else {
                    if (container) container.style.display = 'none';
                    if (currentPreview) currentPreview.style.display = 'block';
                  }
                });
              }

              document.addEventListener('turbo:load', initImagePreview);
              if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', initImagePreview);
              } else {
                initImagePreview();
              }
            })();
          JS
        end)
      end
    end

    row do
      col(sm: 6) do
        number_field :position, label: "Позиция"
      end
      col(sm: 6) do
        check_box :active, label: "Активен"
      end
    end
  end

  controller do
    def create
      @instance = HomeBanner.new(home_banner_params)
      if @instance.save
        adjust_positions_on_create
        redirect_to admin.instance_path(@instance), notice: "Баннер успешно создан"
      else
        render :new
      end
    end

    def update
      @instance = admin.find_instance(params)
      old_position = @instance.position
      old_section = @instance.section
      
      if @instance.update(home_banner_params)
        # Adjust positions if position or section changed
        if old_position != @instance.position || old_section != @instance.section
          adjust_positions_on_update(@instance, old_position, old_section)
        end
        redirect_to admin.instance_path(@instance), notice: "Баннер успешно обновлен"
      else
        render :edit
      end
    end

    def show
      @banner = admin.find_instance(params)
      render "trestle/home_banners/show"
    end

    private
    def home_banner_params
      permitted = params.require(:home_banner).permit(
        :section, :variant, :title, :subtitle, :category_id, :position, :active, :image
      )
      permitted[:category_id] = nil if permitted[:category_id].blank?
      if permitted.key?(:active)
        permitted[:active] = case permitted[:active]
        when "1", "true", true
          true
        when "0", "false", false, nil
          false
        else
          permitted[:active]
        end
      end
      permitted
    end


    def adjust_positions_on_create
      # If position is taken, shift others up
      same_section_banners = HomeBanner.where(section: @instance.section)
                                       .where.not(id: @instance.id)
                                       .where('position >= ?', @instance.position)
      
      same_section_banners.update_all('position = position + 1')
    end

    def adjust_positions_on_update(banner, old_position, old_section)
      new_position = banner.position
      same_section_banners = HomeBanner.where(section: banner.section)
                                       .where.not(id: banner.id)
      
      if old_section != banner.section
        # Section changed - adjust positions in both sections
        # Shift down in old section (close gap left by moving banner)
        HomeBanner.where(section: old_section)
                  .where('position > ?', old_position)
                  .update_all('position = position - 1')
        # Shift up in new section (make room for moved banner)
        same_section_banners.where('position >= ?', new_position)
                           .update_all('position = position + 1')
      elsif new_position > old_position
        # Moving down - shift banners in between up
        same_section_banners.where('position > ? AND position <= ?', old_position, new_position)
                           .update_all('position = position - 1')
      elsif new_position < old_position
        # Moving up - shift banners in between down
        same_section_banners.where('position >= ? AND position < ?', new_position, old_position)
                           .update_all('position = position + 1')
      end
    end
  end

  params do |params|
    permitted = params.require(:home_banner).permit(
      :section, :variant, :title, :subtitle, :category_id, :position, :active, :image
    )
    # Normalize empty category_id to nil
    permitted[:category_id] = nil if permitted[:category_id].blank?
    # Normalize active checkbox - Trestle sends "1" or "0" as string, or true/false
    if permitted.key?(:active)
      permitted[:active] = case permitted[:active]
      when "1", "true", true
        true
      when "0", "false", false, nil
        false
      else
        permitted[:active]
      end
    end
    permitted
  end
end
