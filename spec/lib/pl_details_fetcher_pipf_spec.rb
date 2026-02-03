require 'rails_helper'

RSpec.describe PlDetailsFetcher do
  describe '.parse_html (PIPF секции без модального DOM)' do
    it 'extracts product info, dimensions and extended sections by headings' do
      html = File.read(Rails.root.join('spec/fixtures/files/ikea_pipf_sample.html'))

      result = described_class.parse_html(html, 'https://www.ikea.com/pl/pl/p/sample-70582542/', use_headless: false)

      # Basic
      expect(result[:name]).to eq('SKOENABAECK')
      expect(result[:sku]).to eq('70582542')

      # Product info section
      expect(result[:short_description]).to include('Ta sofa jest wygodna')
      expect(result[:description]).to include('Pokrowiec można łatwo zdjąć')

      # Materials & care (from section-based extraction in extract_modal_details)
      expect(result[:materials]).to include('Rama: Stal')
      expect(result[:materials]).to include('Tkanina: 100% poliester')
      expect(result[:care_instructions]).to include('Odkurzać regularnie')

      # Safety / good to know
      expect(result[:safety_info]).to include('Nie stawać na sofie')
      expect(result[:good_to_know]).to include('W zestawie komplet śrub')

      # Dimensions string should be derived by extract_packaging_info regex fallback
      expect(result[:dimensions]).to include('158')
      expect(result[:dimensions]).to include('75')
      expect(result[:dimensions]).to include('74')
    end
  end
end
