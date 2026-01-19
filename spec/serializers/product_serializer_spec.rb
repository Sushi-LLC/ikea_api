require "rails_helper"
require "securerandom"

RSpec.describe ProductSerializer do
  describe "breadcrumbs attribute" do
    let(:category) do
      Category.create!(
        ikea_id: "cat-1",
        name: "Primary Category",
        parent_ids: []
      )
    end
    let(:product) do
      Product.create!(
        sku: "SKU-#{SecureRandom.uuid}",
        name: "Serializable Product",
        category_id: category.ikea_id
      )
    end

    before do
      BreadcrumbRule.delete_all
      BreadcrumbRule.create!(entity_type: "product", rule_type: :by_primary_category_only, active: true)
    end

    it "exposes breadcrumbs when detail flag is present" do
      serialized = described_class.new(product, params: { detail: true }).serializable_hash

      expect(serialized[:data][:attributes][:breadcrumbs]).to eq([
        { title: category.name, url: "/category/#{category.ikea_id}" }
      ])
    end

    it "does not include breadcrumbs when detail flag is missing" do
      serialized = described_class.new(product).serializable_hash

      expect(serialized[:data][:attributes]).not_to have_key(:breadcrumbs)
    end
  end
end
