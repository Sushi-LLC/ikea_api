Trestle.resource(:users, model: User) do
  menu do
    item :users, icon: "fa fa-users", priority: 5, label: "Пользователи", group: "Settings"
  end

  table do
    column :id
    column :username, link: true
    column :email
    column :role do |user|
      case user.role
      when 'admin'
        status_tag('Администратор', :success)
      when 'manager'
        status_tag('Менеджер', :info)
      else
        status_tag('Пользователь', :secondary)
      end
    end
    column :is_active do |user|
      status_tag(user.is_active? ? 'Активен' : 'Неактивен', 
                 user.is_active? ? :success : :danger)
    end
    column :created_at, align: :center
    actions
  end

  form do |user|
    text_field :username
    text_field :email
    password_field :password
    password_field :password_confirmation
    select :role, { 'Пользователь' => 'user', 'Менеджер' => 'manager', 'Администратор' => 'admin' }
    check_box :is_active
  end
end

