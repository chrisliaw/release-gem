# frozen_string_literal: true

RSpec.describe Release::Gem do
  it "has a version number" do
    expect(Release::Gem::VERSION).not_to be nil
  end

end
