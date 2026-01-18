FactoryBot.define do
  factory :content_article do
    sequence(:title) { |n| "Content Article #{n}" }
    sequence(:slug) { |n| "content-article-#{n}" }
    excerpt { "Описание контента" }
    status { :draft }
    content_type { :tips_ideas }
    body_blocks { [] }
  end
end
