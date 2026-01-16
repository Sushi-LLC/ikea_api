class DropDeprecatedHomepageTables < ActiveRecord::Migration[7.1]
  def change
    drop_table :homepage_product_block_items, if_exists: true
    drop_table :homepage_product_block_rules, if_exists: true
    drop_table :homepage_product_blocks, if_exists: true
    drop_table :home_slider_banners, if_exists: true
    drop_table :home_sliders, if_exists: true
  end
end
