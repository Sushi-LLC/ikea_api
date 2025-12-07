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

ActiveRecord::Schema[7.1].define(version: 2025_12_06_083851) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "deliveries", force: :cascade do |t|
    t.decimal "weight"
    t.string "delivery_type"
    t.boolean "is_ikea_family"
    t.decimal "order_value"
    t.boolean "is_weekend"
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
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["is_bestseller"], name: "index_products_on_is_bestseller"
    t.index ["is_popular"], name: "index_products_on_is_popular"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["unique_id"], name: "index_products_on_unique_id", unique: true, where: "(unique_id IS NOT NULL)"
    t.index ["updated_at"], name: "index_products_on_updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "email"
    t.string "password_digest"
    t.string "role", default: "user"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "filter_values", "filters"
  add_foreign_key "product_filter_values", "filter_values"
  add_foreign_key "product_filter_values", "products"
end
