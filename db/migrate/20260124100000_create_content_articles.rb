class CreateContentArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :content_articles do |t|
      t.integer :content_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt
      t.jsonb :body_blocks, null: false, default: []
      t.jsonb :tile_blocks, null: false, default: []
      t.jsonb :components, null: false, default: []
      t.jsonb :projects, null: false, default: []
      t.jsonb :tags, null: false, default: []
      t.boolean :pinned, null: false, default: false
      t.integer :pinned_position, null: false, default: 0
      t.datetime :published_at
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :content_articles, :slug, unique: true
    add_index :content_articles, :components, using: :gin
    add_index :content_articles, :projects, using: :gin
    add_index :content_articles, :tags, using: :gin
    add_index :content_articles, [:content_type, :status, :pinned, :pinned_position, :published_at, :active], name: "index_content_articles_on_status_and_filters"

    create_table :content_article_products do |t|
      t.bigint :content_article_id, null: false
      t.string :product_sku, null: false
      t.integer :position, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.timestamps
    end

    add_index :content_article_products, :content_article_id
    add_index :content_article_products, :product_sku
    add_index :content_article_products, [:content_article_id, :product_sku], unique: true, name: "index_content_article_products_on_article_and_sku"

    create_table :content_article_categories do |t|
      t.bigint :content_article_id, null: false
      t.string :category_id, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :content_article_categories, :content_article_id
    add_index :content_article_categories, :category_id
    add_index :content_article_categories, [:content_article_id, :category_id], unique: true, name: "index_content_article_categories_on_article_and_category"
  end
end
