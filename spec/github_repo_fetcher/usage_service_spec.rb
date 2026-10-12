# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GithubRepoFetcher::UsageService do
  describe '.json' do
    subject(:usage) { described_class.json }

    it 'documents the projects endpoint with a username placeholder' do
      expect(usage[:endpoints][:projects]).to eq('/api/projects?username={github_username}')
    end

    it 'keeps a working example for every endpoint' do
      expect(usage[:examples]).to eq(health: '/api/health', projects: '/api/projects?username=octocat')
    end

    it 'describes limits and errors' do
      expect(usage).to include(:parameters, :limits, :errors)
    end
  end

  describe '.html_requested?' do
    it 'is true for a browser Accept header' do
      request = { 'accept' => 'text/html,application/xhtml+xml,*/*;q=0.8' }
      expect(described_class.html_requested?(request)).to be(true)
    end

    it 'is true when the Accept header is nested under headers' do
      request = { 'headers' => { 'accept' => 'text/html' } }
      expect(described_class.html_requested?(request)).to be(true)
    end

    it 'is false for curl-style Accept headers' do
      expect(described_class.html_requested?({ 'accept' => '*/*' })).to be(false)
    end

    it 'is false when there is no Accept header' do
      expect(described_class.html_requested?({})).to be(false)
    end

    it 'lets ?format=json override a browser Accept header' do
      request = Struct.new(:query) do
        def [](_key)
          'text/html'
        end
      end.new({ 'format' => 'json' })

      expect(described_class.html_requested?(request)).to be(false)
    end
  end

  describe '.html' do
    it 'is a complete HTML document' do
      expect(described_class.html).to start_with('<!DOCTYPE html>').and include('</html>')
    end

    it 'links the documented endpoints' do
      expect(described_class.html).to include('/api/projects?username=', '/api/health')
    end
  end
end
