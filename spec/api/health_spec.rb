# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'api/health.rb', :aggregate_failures, type: :handler do
  let(:service) { instance_double(GithubRepoFetcher::HealthService) }

  before do
    allow(GithubRepoFetcher::HealthService).to receive(:new).and_return(service)
  end

  it 'returns 200 with short caching when healthy' do
    allow(service).to receive(:check_health).and_return(status: 'healthy')

    response = run_handler('health', path: '/api/health')

    expect(response.status).to eq(200)
    expect(response.json).to eq('status' => 'healthy')
    expect(response['Cache-Control']).to eq('s-maxage=10, stale-while-revalidate=60')
  end

  it 'returns 503 when unhealthy' do
    allow(service).to receive(:check_health).and_return(status: 'unhealthy', error: 'boom')

    response = run_handler('health', path: '/api/health')

    expect(response.status).to eq(503)
    expect(response.json['status']).to eq('unhealthy')
  end

  it 'returns 503 when the check itself raises' do
    allow(service).to receive(:check_health).and_raise(StandardError, 'down')

    response = run_handler('health', path: '/api/health')

    expect([response.status, response.json]).to eq([503, { 'error' => 'down' }])
  end

  it 'answers CORS preflight' do
    response = run_handler('health', method: 'OPTIONS')

    expect([response.status, response.body]).to eq([200, ''])
  end
end
