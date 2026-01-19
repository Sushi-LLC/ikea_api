require "rails_helper"
require "securerandom"

RSpec.describe Seo::BreadcrumbsBuilder do
  describe ".for_product" do
    let(:product) { Product.create!(sku: "SKU-#{SecureRandom.uuid}", name: "Test product") }
    let!(:root_category) do
      Category.create!(
        ikea_id: "root",
        name: "Root Category",
        parent_ids: []
      )
    end
    let!(:child_category) do
      Category.create!(
        ikea_id: "child",
        name: "Child Category",
        parent_ids: [root_category.ikea_id]
      )
    end

    before do
      product.update!(category_id: child_category.ikea_id)
      BreadcrumbRule.delete_all
    end

    it "builds a tree when tree rule is active" do
      BreadcrumbRule.create!(entity_type: "product", rule_type: :by_primary_category_tree, active: true)

      expect(described_class.for_product(product)).to eq([
        { title: root_category.name, url: "/category/#{root_category.ikea_id}" },
        { title: child_category.name, url: "/category/#{child_category.ikea_id}" }
      ])
    end

    it "returns only the primary category when simplified rule is active" do
      BreadcrumbRule.create!(entity_type: "product", rule_type: :by_primary_category_only, active: true)

      expect(described_class.for_product(product)).to eq([
        { title: child_category.name, url: "/category/#{child_category.ikea_id}" }
      ])
    end

    it "returns empty array when there is no primary category" do
      BreadcrumbRule.create!(entity_type: "product", rule_type: :by_primary_category_tree, active: true)
      product.update!(category_id: nil)

      expect(described_class.for_product(product)).to eq([])
    end

    it "returns empty array when there is no active rule" do
      expect(described_class.for_product(product)).to eq([])
    end
  end
end
