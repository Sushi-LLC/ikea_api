# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_02_06_131804) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "breadcrumb_rules", force: :cascade do |t|
    t.string "entity_type", null: false
    t.integer "rule_type", default: 0, null: false
    t.jsonb "payload", default: {}
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_type"], name: "index_breadcrumb_rules_on_entity_type"
  end

  create_table "calculator_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value", null: false
    t.string "setting_type", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_calculator_settings_on_key", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.string "product_sku", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_sku"], name: "index_cart_items_on_cart_id_and_product_sku", unique: true
    t.index ["product_sku"], name: "index_cart_items_on_product_sku"
  end

  create_table "carts", force: :cascade do |t|
    t.string "guest_token", null: false
    t.datetime "expires_at", null: false
    t.bigint "promo_code_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["expires_at"], name: "index_carts_on_expires_at"
    t.index ["guest_token"], name: "index_carts_on_guest_token", unique: true
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "ikea_id"
    t.integer "unique_id"
    t.string "name"
    t.string "translated_name"
    t.string "url"
    t.string "remote_image_url"
    t.string "local_image_path"
    t.text "parent_ids"
    t.boolean "is_deleted"
    t.boolean "is_important"
    t.boolean "is_popular"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, COALESCE(parent_ids, ''::text))", name: "index_categories_on_parent_ids_text", where: "((parent_ids IS NOT NULL) AND (parent_ids <> '[]'::text) AND (parent_ids <> ''::text))", using: :gin
    t.index ["ikea_id"], name: "index_categories_on_ikea_id", unique: true
    t.index ["is_popular"], name: "index_categories_on_is_popular"
    t.index ["parent_ids"], name: "index_categories_on_parent_ids_btree", where: "((parent_ids IS NOT NULL) AND (parent_ids <> '[]'::text) AND (parent_ids <> ''::text))"
    t.index ["unique_id"], name: "index_categories_on_unique_id", unique: true, where: "(unique_id IS NOT NULL)"
  end

  create_table "category_products", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_products_on_category_id"
    t.index ["product_id", "category_id"], name: "index_category_products_unique", unique: true
    t.index ["product_id"], name: "index_category_products_on_product_id"
  end

  create_table "content_article_categories", force: :cascade do |t|
    t.bigint "content_article_id", null: false
    t.string "category_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_content_article_categories_on_category_id"
    t.index ["content_article_id", "category_id"], name: "index_content_article_categories_on_article_and_category", unique: true
    t.index ["content_article_id"], name: "index_content_article_categories_on_content_article_id"
  end

  create_table "content_article_products", force: :cascade do |t|
    t.bigint "content_article_id", null: false
    t.string "product_sku", null: false
    t.integer "position", default: 0, null: false
    t.integer "source", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_article_id", "product_sku"], name: "index_content_article_products_on_article_and_sku", unique: true
    t.index ["content_article_id"], name: "index_content_article_products_on_content_article_id"
    t.index ["product_sku"], name: "index_content_article_products_on_product_sku"
  end

  create_table "content_articles", force: :cascade do |t|
    t.integer "content_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.text "excerpt"
    t.jsonb "body_blocks", default: [], null: false
    t.jsonb "tile_blocks", default: [], null: false
    t.jsonb "components", default: [], null: false
    t.jsonb "projects", default: [], null: false
    t.jsonb "tags", default: [], null: false
    t.boolean "pinned", default: false, null: false
    t.integer "pinned_position", default: 0, null: false
    t.datetime "published_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["components"], name: "index_content_articles_on_components", using: :gin
    t.index ["content_type", "status", "pinned", "pinned_position", "published_at", "active"], name: "index_content_articles_on_status_and_filters"
    t.index ["projects"], name: "index_content_articles_on_projects", using: :gin
    t.index ["slug"], name: "index_content_articles_on_slug", unique: true
    t.index ["tags"], name: "index_content_articles_on_tags", using: :gin
  end

  create_table "cron_schedules", force: :cascade do |t|
    t.string "task_type", null: false
    t.string "schedule", null: false
    t.boolean "enabled", default: true
    t.datetime "last_run_at"
    t.datetime "next_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_cron_schedules_on_enabled"
    t.index ["next_run_at"], name: "index_cron_schedules_on_next_run_at"
    t.index ["task_type"], name: "index_cron_schedules_on_task_type", unique: true
  end

  create_table "deliveries", force: :cascade do |t|
    t.decimal "weight"
    t.string "delivery_type"
    t.boolean "is_ikea_family"
    t.decimal "order_value"
    t.boolean "is_weekend"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "exchange_rates", force: :cascade do |t|
    t.date "date", null: false
    t.string "currency_code", null: false
    t.decimal "rate", precision: 10, scale: 4, null: false
    t.decimal "official_rate", precision: 10, scale: 4
    t.integer "scale", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_code"], name: "index_exchange_rates_on_currency_code"
    t.index ["date", "currency_code"], name: "index_exchange_rates_on_date_and_currency_code", unique: true
  end

  create_table "feed_settings", force: :cascade do |t|
    t.boolean "feeds_enabled", default: true, null: false
    t.integer "feed_access_mode", default: 0, null: false
    t.string "feed_token"
    t.string "base_url", default: "https://example.com", null: false
    t.string "currency_default", default: "BYN", null: false
    t.string "store_name"
    t.string "store_company"
    t.string "store_platform_brand"
    t.jsonb "availability_mapping", default: {"in_stock"=>"in stock", "preorder"=>"preorder", "out_of_stock"=>"out of stock"}, null: false
    t.decimal "yml_delivery_cost", precision: 10, scale: 2
    t.integer "yml_delivery_days"
    t.boolean "include_out_of_stock", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "filter_values", force: :cascade do |t|
    t.bigint "filter_id", null: false
    t.string "value_id"
    t.string "name"
    t.string "name_ru"
    t.string "hex"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["filter_id"], name: "index_filter_values_on_filter_id"
    t.index ["value_id"], name: "index_filter_values_on_value_id", unique: true
  end

  create_table "filters", force: :cascade do |t|
    t.string "parameter"
    t.string "name"
    t.string "name_ru"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parameter"], name: "index_filters_on_parameter", unique: true
  end

  create_table "home_banners", force: :cascade do |t|
    t.integer "section", default: 0, null: false
    t.integer "variant", default: 0, null: false
    t.string "title"
    t.string "subtitle"
    t.string "category_id"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_home_banners_on_category_id"
    t.index ["section", "active", "position"], name: "index_home_banners_on_section_and_active_and_position"
  end

  create_table "home_slider_banners", force: :cascade do |t|
    t.bigint "home_slider_id", null: false
    t.integer "position", default: 0, null: false
    t.string "link_url"
    t.string "title"
    t.string "subtitle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["home_slider_id", "position"], name: "index_home_slider_banners_on_home_slider_id_and_position"
    t.index ["home_slider_id"], name: "index_home_slider_banners_on_home_slider_id"
  end

  create_table "home_sliders", force: :cascade do |t|
    t.string "title"
    t.integer "layout_type", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "starts_at", "ends_at"], name: "index_home_sliders_on_active_and_starts_at_and_ends_at"
    t.index ["active"], name: "index_home_sliders_on_active"
    t.index ["position"], name: "index_home_sliders_on_position"
  end

  create_table "homepage_product_block_items", force: :cascade do |t|
    t.bigint "homepage_product_block_id", null: false
    t.string "product_id", null: false
    t.integer "position", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["homepage_product_block_id", "position"], name: "idx_on_homepage_product_block_id_position_e9e5de2d57"
    t.index ["homepage_product_block_id"], name: "idx_on_homepage_product_block_id_686cddbf3a"
    t.index ["product_id"], name: "index_homepage_product_block_items_on_product_id"
    t.index ["starts_at", "ends_at"], name: "index_homepage_product_block_items_on_starts_at_and_ends_at"
  end

  create_table "homepage_product_block_rules", force: :cascade do |t|
    t.bigint "homepage_product_block_id", null: false
    t.string "rule_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["homepage_product_block_id", "rule_type"], name: "idx_on_homepage_product_block_id_rule_type_9216ece37d"
    t.index ["homepage_product_block_id"], name: "idx_on_homepage_product_block_id_b9d3beedce"
    t.index ["payload"], name: "index_homepage_product_block_rules_on_payload", using: :gin
  end

  create_table "homepage_product_blocks", force: :cascade do |t|
    t.string "key", null: false
    t.string "title", null: false
    t.boolean "active", default: true, null: false
    t.integer "limit", default: 10, null: false
    t.integer "source_type", default: 0, null: false
    t.integer "category_level", default: 1
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_homepage_product_blocks_on_active"
    t.index ["key"], name: "index_homepage_product_blocks_on_key", unique: true
    t.index ["position"], name: "index_homepage_product_blocks_on_position"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "product_sku", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_sku"], name: "index_order_items_on_order_id_and_product_sku", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_sku"], name: "index_order_items_on_product_sku"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "crm_external_id"
    t.string "country"
    t.integer "status", default: 0, null: false
    t.datetime "purchased_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crm_external_id"], name: "index_orders_on_crm_external_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "parser_tasks", force: :cascade do |t|
    t.string "task_type", null: false
    t.string "status", default: "pending"
    t.integer "limit"
    t.integer "processed", default: 0
    t.integer "created", default: 0
    t.integer "updated", default: 0
    t.integer "error_count", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "job_id"
    t.index ["created_at"], name: "index_parser_tasks_on_created_at"
    t.index ["job_id"], name: "index_parser_tasks_on_job_id"
    t.index ["status"], name: "index_parser_tasks_on_status"
    t.index ["task_type", "status"], name: "index_parser_tasks_on_task_type_and_status"
    t.index ["task_type"], name: "index_parser_tasks_on_task_type"
  end

  create_table "popular_search_queries", force: :cascade do |t|
    t.string "query", null: false
    t.integer "weight", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_popular_search_queries_on_active"
    t.index ["query"], name: "index_popular_search_queries_on_query"
  end

  create_table "product_filter_values", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "filter_value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["filter_value_id"], name: "index_product_filter_values_on_filter_value_id"
    t.index ["product_id"], name: "index_product_filter_values_on_product_id"
  end

  create_table "product_title_templates", force: :cascade do |t|
    t.string "key", null: false
    t.text "template_string"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_product_title_templates_on_key", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "sku"
    t.integer "unique_id"
    t.string "item_no"
    t.string "url"
    t.string "name"
    t.string "name_ru"
    t.string "collection"
    t.text "variants"
    t.text "related_products"
    t.text "set_items"
    t.text "bundle_items"
    t.text "images"
    t.text "local_images"
    t.integer "images_total"
    t.integer "images_stored"
    t.boolean "images_incomplete"
    t.text "videos"
    t.text "manuals"
    t.decimal "price"
    t.integer "quantity"
    t.string "home_delivery"
    t.decimal "weight"
    t.decimal "net_weight"
    t.decimal "package_volume"
    t.string "package_dimensions"
    t.string "dimensions"
    t.boolean "is_parcel"
    t.text "content"
    t.text "content_ru"
    t.text "material_info"
    t.text "material_info_ru"
    t.text "good_info"
    t.text "good_info_ru"
    t.boolean "translated"
    t.boolean "is_bestseller"
    t.boolean "is_popular"
    t.string "category_id"
    t.string "delivery_type"
    t.string "delivery_name"
    t.decimal "delivery_cost"
    t.string "delivery_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "materials"
    t.text "features"
    t.text "care_instructions"
    t.text "environmental_info"
    t.text "short_description"
    t.string "designer"
    t.text "safety_info"
    t.text "good_to_know"
    t.text "assembly_documents"
    t.text "materials_ru"
    t.text "features_ru"
    t.text "care_instructions_ru"
    t.text "environmental_info_ru"
    t.text "short_description_ru"
    t.string "designer_ru"
    t.text "safety_info_ru"
    t.text "good_to_know_ru"
    t.decimal "rating_avg", precision: 4, scale: 2, default: "0.0", null: false
    t.decimal "rating_weighted", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "rating_count", default: 0, null: false
    t.datetime "rating_updated_at"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["is_bestseller"], name: "index_products_on_is_bestseller"
    t.index ["is_popular"], name: "index_products_on_is_popular"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["unique_id"], name: "index_products_on_unique_id", unique: true, where: "(unique_id IS NOT NULL)"
    t.index ["updated_at"], name: "index_products_on_updated_at"
  end

  create_table "promo_code_products", force: :cascade do |t|
    t.bigint "promo_code_id", null: false
    t.string "product_sku", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_sku"], name: "index_promo_code_products_on_product_sku"
    t.index ["promo_code_id", "product_sku"], name: "index_promo_code_products_on_promo_code_id_and_product_sku", unique: true
  end

  create_table "promo_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "name"
    t.integer "discount_type", null: false
    t.decimal "discount_value", precision: 12, scale: 2, null: false
    t.boolean "active", default: true, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "ends_at"], name: "index_promo_codes_on_active_and_ends_at"
    t.index ["code"], name: "index_promo_codes_on_code", unique: true
  end

  create_table "review_helpful_votes", force: :cascade do |t|
    t.bigint "review_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id", "user_id"], name: "index_review_helpful_votes_on_review_id_and_user_id", unique: true
    t.index ["review_id"], name: "index_review_helpful_votes_on_review_id"
    t.index ["user_id"], name: "index_review_helpful_votes_on_user_id"
  end

  create_table "review_settings", force: :cascade do |t|
    t.decimal "helpful_weight_factor", precision: 5, scale: 4, default: "0.1", null: false
    t.decimal "base_weight", precision: 5, scale: 2, default: "1.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "product_sku", null: false
    t.bigint "order_id"
    t.integer "rating", null: false
    t.text "body", null: false
    t.integer "status", default: 0, null: false
    t.datetime "published_at"
    t.text "admin_note"
    t.boolean "pinned", default: false, null: false
    t.boolean "excluded_from_rating", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_reviews_on_order_id"
    t.index ["product_sku"], name: "index_reviews_on_product_sku"
    t.index ["status"], name: "index_reviews_on_status"
    t.index ["user_id", "product_sku"], name: "index_reviews_on_user_id_and_product_sku", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "search_query_logs", force: :cascade do |t|
    t.bigint "customer_id"
    t.string "query", null: false
    t.integer "results_count", default: 0, null: false
    t.string "clicked_product_sku"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_search_query_logs_on_customer_id"
    t.index ["query"], name: "index_search_query_logs_on_query"
  end

  create_table "translation_caches", force: :cascade do |t|
    t.text "text", null: false
    t.string "target_language", limit: 10, null: false
    t.string "source_language", limit: 10, null: false
    t.text "translated_text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["text", "target_language", "source_language"], name: "index_translation_caches_on_text_and_languages", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "email"
    t.string "password_digest"
    t.string "role", default: "user"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "remember_token"
    t.datetime "remember_token_expires_at"
    t.string "phone"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "verification_codes", force: :cascade do |t|
    t.string "phone", null: false
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone"], name: "index_verification_codes_on_phone"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "carts", "promo_codes"
  add_foreign_key "carts", "users"
  add_foreign_key "category_products", "products"
  add_foreign_key "filter_values", "filters"
  add_foreign_key "home_banners", "categories", primary_key: "ikea_id", on_delete: :nullify
  add_foreign_key "home_slider_banners", "home_sliders"
  add_foreign_key "homepage_product_block_items", "homepage_product_blocks"
  add_foreign_key "homepage_product_block_items", "products", primary_key: "sku"
  add_foreign_key "homepage_product_block_rules", "homepage_product_blocks"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "users"
  add_foreign_key "product_filter_values", "filter_values"
  add_foreign_key "product_filter_values", "products"
  add_foreign_key "promo_code_products", "promo_codes"
  add_foreign_key "review_helpful_votes", "reviews"
  add_foreign_key "review_helpful_votes", "users"
  add_foreign_key "reviews", "orders"
  add_foreign_key "reviews", "users"
  add_foreign_key "search_query_logs", "users", column: "customer_id"
end
