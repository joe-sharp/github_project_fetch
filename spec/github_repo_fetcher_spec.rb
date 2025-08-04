# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GithubRepoFetcher do
  it 'is defined as a module' do
    expect(described_class).to be_a(Module)
  end

  it 'has GithubClient class' do
    expect(described_class::GithubClient).to be_a(Class)
  end
end
