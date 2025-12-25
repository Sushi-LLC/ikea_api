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

ActiveRecord::Schema[7.1].define(version: 2025_12_23_215130) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "calculator_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value", null: false
    t.string "setting_type", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_calculator_settings_on_key", unique: true
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
    t.index ["ikea_id"], name: "index_categories_on_ikea_id", unique: true
    t.index ["is_popular"], name: "index_categories_on_is_popular"
    t.index ["unique_id"], name: "index_categories_on_unique_id", unique: true, where: "(unique_id IS NOT NULL)"
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

  create_table "product_filter_values", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "filter_value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["filter_value_id"], name: "index_product_filter_values_on_filter_value_id"
    t.index ["product_id"], name: "index_product_filter_values_on_product_id"
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
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["is_bestseller"], name: "index_products_on_is_bestseller"
    t.index ["is_popular"], name: "index_products_on_is_popular"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["unique_id"], name: "index_products_on_unique_id", unique: true, where: "(unique_id IS NOT NULL)"
    t.index ["updated_at"], name: "index_products_on_updated_at"
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
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "filter_values", "filters"
  add_foreign_key "product_filter_values", "filter_values"
  add_foreign_key "product_filter_values", "products"
end
