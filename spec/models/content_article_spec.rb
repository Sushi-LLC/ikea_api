require "rails_helper"
require "stringio"

RSpec.describe ContentArticle, type: :model do
  around do |example|
    original_host = Rails.application.routes.default_url_options[:host]
    Rails.application.routes.default_url_options[:host] = "http://test.host"
    example.run
    Rails.application.routes.default_url_options[:host] = original_host
  end

  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake-image"),
      filename: "hero.png",
      content_type: "image/png"
    )
  end

  describe "body block uploads" do
    it "attaches referenced block images" do
      template = ContentArticle::BODY_BLOCK_TEMPLATES.first
      slot_name = template[:image_slots].first[:name]
      article = build(:content_article)
      article.body_blocks = [
        {
          "type" => template[:id],
          "content" => "<p>Описание</p>",
          "images" => [
            { "slot" => slot_name, "signed_id" => blob.signed_id }
          ]
        }
      ]

      article.save!

      attached_ids = article.body_block_images.map(&:signed_id)
      expect(attached_ids).to include(blob.signed_id)
    end
  end

  describe "serializer body blocks" do
    it "exposes image urls and button category data" do
      template = ContentArticle::BODY_BLOCK_TEMPLATES.find { |tpl| tpl[:button_enabled] }
      slot_name = template[:image_slots].first[:name]
      category = create(:category, ikea_id: "123", name: "Гостиная")

      article = create(:content_article, body_blocks: [
        {
          "type" => template[:id],
          "content" => "<p>Слайдер</p>",
          "button_text" => "Вдохновение",
          "button_category_id" => category.ikea_id,
          "images" => [
            { "slot" => slot_name, "signed_id" => blob.signed_id }
          ]
        }
      ])

      serialized = ContentArticleSerializer.new(article).serializable_hash
      serialized_blocks = serialized[:data][:attributes][:body_blocks]

      expect(serialized_blocks.length).to eq(1)
      expect(serialized_blocks.first["images"].first["url"]).to include("/rails/active_storage/blobs")
      expect(serialized_blocks.first["button_category"]["ikea_id"]).to eq(category.ikea_id)
      expect(serialized_blocks.first["button_category"]["name"]).to eq(category.name)
    end
  end
end
