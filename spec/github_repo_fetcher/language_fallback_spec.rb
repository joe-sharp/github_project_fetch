# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GithubRepoFetcher::LanguageFallback do
  let(:entry) { Data.define(:path, :type, :size) }

  describe '.from_tree' do
    it 'sums blob sizes per language' do
      entries = [entry.new('a.yml', 'blob', 10), entry.new('b.yaml', 'blob', 5), entry.new('c.json', 'blob', 7)]

      expect(described_class.from_tree(entries)).to eq('YAML' => 15, 'JSON' => 7)
    end

    it 'maps md and markdown to Markdown' do
      entries = [entry.new('README.md', 'blob', 4), entry.new('docs/x.markdown', 'blob', 6)]

      expect(described_class.from_tree(entries)).to eq('Markdown' => 10)
    end

    it 'matches extensions case-insensitively' do
      expect(described_class.from_tree([entry.new('CONFIG.YML', 'blob', 3)])).to eq('YAML' => 3)
    end

    it 'ignores trees and unknown extensions' do
      entries = [entry.new('dir.json', 'tree', 99), entry.new('main.rb', 'blob', 50), entry.new('LICENSE', 'blob', 8)]

      expect(described_class.from_tree(entries)).to eq({})
    end

    it 'treats a missing size as zero' do
      expect(described_class.from_tree([entry.new('a.json', 'blob', nil)])).to eq('JSON' => 0)
    end
  end

  describe '.fetch' do
    let(:client) { instance_double(Octokit::Client) }

    it 'returns an empty hash without a branch' do
      expect(described_class.fetch(client, 'octocat/hello', nil)).to eq({})
    end

    it 'reads the recursive git tree of the branch' do
      tree = Struct.new(:tree).new([entry.new('a.md', 'blob', 12)])
      allow(client).to receive(:tree).with('octocat/hello', 'main', recursive: true).and_return(tree)

      expect(described_class.fetch(client, 'octocat/hello', 'main')).to eq('Markdown' => 12)
    end
  end
end
