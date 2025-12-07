class AddIndexes < ActiveRecord::Migration[7.1]
  def change
    # Products
    # sku index уже создан в create_products - пропускаем
    add_index :products, :unique_id, unique: true, where: "unique_id IS NOT NULL" unless index_exists?(:products, :unique_id)
    add_index :products, :category_id unless index_exists?(:products, :category_id)
    add_index :products, :is_bestseller unless index_exists?(:products, :is_bestseller)
    add_index :products, :is_popular unless index_exists?(:products, :is_popular)
    add_index :products, :updated_at unless index_exists?(:products, :updated_at)
    
    # Categories
    # ikea_id index уже создан в create_categories - пропускаем
    add_index :categories, :unique_id, unique: true, where: "unique_id IS NOT NULL" unless index_exists?(:categories, :unique_id)
    add_index :categories, :is_popular unless index_exists?(:categories, :is_popular)
    
    # Filters
    # parameter index уже создан в create_filters - пропускаем
    
    # FilterValues
    # value_id index уже создан в create_filter_values - пропускаем
    add_index :filter_values, :filter_id unless index_exists?(:filter_values, :filter_id)
    
    # Users
    # username index уже создан в create_users - пропускаем
    add_index :users, :email, unique: true, where: "email IS NOT NULL" unless index_exists?(:users, :email)
  end
end
