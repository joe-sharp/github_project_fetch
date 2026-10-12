# frozen_string_literal: true

#
# E2E API contract tests
# ======================
# Run against a deployment (Vercel preview or production). Excluded from the default
# suite because they need network access to a live deployment.
#
#   bin/test_api.rb                          # production
#   bin/test_api.rb <preview deployment URL>
#   VERCEL_URL=<url> RUN_E2E=true bundle exec rspec --tag e2e
#
# Previews are protected, so set VERCEL_AUTOMATION_BYPASS_SECRET for them.
# The deployment rate limits to 60 requests / 5 min / IP, so keep the request count small.

require 'spec_helper'

RSpec.describe 'Deployed API', :e2e do
  let(:usage_keys) { %w[name version endpoints parameters examples limits errors] }
  let(:project_keys) do
    %w[name description languages forks_count stargazers_count html_url created_at updated_at]
  end

  describe 'GET /api' do
    it 'serves JSON usage by default', :aggregate_failures do
      response = E2eClient.request('/api')

      expect(response.code).to eq('200')
      expect(response['content-type']).to include('application/json')
      expect(response['vary']).to include('Accept')
      expect(E2eClient.json(response)).to include(*usage_keys)
    end

    it 'serves the HTML guide when HTML is requested', :aggregate_failures do
      response = E2eClient.request('/api', accept: 'text/html')

      expect(response.code).to eq('200')
      expect(response['content-type']).to include('text/html')
      expect(response.body).to include('id="tryForm"')
    end

    it 'serves the HTML guide for ?format=html', :aggregate_failures do
      response = E2eClient.request('/api?format=html')

      expect(response['content-type']).to include('text/html')
    end

    it 'rewrites / to the usage endpoint', :aggregate_failures do
      response = E2eClient.request('/')

      expect(response.code).to eq('200')
      expect(E2eClient.json(response)).to include('endpoints')
    end
  end

  describe 'GET /api/health' do
    it 'reports a healthy GitHub connection', :aggregate_failures do
      response = E2eClient.request('/api/health')
      body = E2eClient.json(response)

      expect(response.code).to eq('200')
      expect(body['status']).to eq('healthy')
      expect(body['rate_limit']).to include('remaining', 'limit', 'reset_time', 'used_percentage')
    end
  end

  describe 'GET /api/projects' do
    let(:response) { E2eClient.request('/api/projects?username=octocat') }
    let(:body) { E2eClient.json(response) }

    it 'returns the documented shape for a real user', :aggregate_failures do
      expect(response.code).to eq('200')
      expect(response['cache-control']).to include('s-maxage=600')
      expect(body).to include('username' => 'octocat', 'projects_count' => body['projects'].length)
      expect(body['projects'].first.keys).to include(*project_keys)
    end

    it 'reports language byte counts as integers', :aggregate_failures do
      languages = body['projects'].flat_map { |project| project['languages'].values }

      expect(languages).not_to be_empty
      expect(languages).to all(be_a(Integer))
    end

    it 'rejects a missing username with 400', :aggregate_failures do
      response = E2eClient.request('/api/projects')

      expect(response.code).to eq('400')
      expect(E2eClient.json(response)['error']).to match(/Username parameter is required/)
    end

    it 'rejects a username longer than 39 characters with 400' do
      response = E2eClient.request("/api/projects?username=#{'a' * 40}")

      expect(response.code).to eq('400')
    end

    it 'rejects unsafe characters with 400' do
      response = E2eClient.request('/api/projects?username=a%3Cb')

      expect(response.code).to eq('400')
    end
  end

  describe 'CORS and routing' do
    it 'answers preflight requests with CORS headers', :aggregate_failures do
      response = E2eClient.request('/api/projects', method: :options)

      expect(response.code).to eq('200')
      expect(response['access-control-allow-origin']).to eq('*')
    end

    it 'sends CORS headers on regular responses' do
      expect(E2eClient.request('/api/health')['access-control-allow-origin']).to eq('*')
    end
  end
end
