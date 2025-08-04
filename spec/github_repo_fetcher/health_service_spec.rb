# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GithubRepoFetcher::HealthService do
  let(:mock_github_client) { instance_double(GithubRepoFetcher::GithubClient) }
  let(:service) { described_class.new(mock_github_client) }

  describe '#initialize' do
    it 'creates a new instance with default github client' do
      # Mock the GithubClient to avoid WebMock issues
      allow(GithubRepoFetcher::GithubClient).to receive(:new).and_return(mock_github_client)
      expect { described_class.new }.not_to raise_error
    end

    it 'creates a new instance with provided github client' do
      expect { described_class.new(mock_github_client) }.not_to raise_error
    end
  end

  describe '#check_health' do
    context 'when github client returns healthy status' do
      let(:healthy_response) do
        {
          status: 'healthy',
          message: 'GitHub API connection successful',
          rate_limit: {
            remaining: 5000,
            limit: 5000,
            reset_time: '2023-01-01T12:00:00Z',
            used_percentage: 0.0
          }
        }
      end

      before do
        allow(mock_github_client).to receive(:health_check).and_return(healthy_response)
      end

      it 'returns the health check response', :aggregate_failures do
        result = service.check_health

        expect(result).to eq(healthy_response)
        expect(mock_github_client).to have_received(:health_check)
      end
    end

    context 'when github client returns unhealthy status' do
      let(:unhealthy_response) do
        {
          status: 'unhealthy',
          message: 'GitHub API error: Rate limit exceeded'
        }
      end

      before do
        allow(mock_github_client).to receive(:health_check).and_return(unhealthy_response)
      end

      it 'returns the unhealthy response', :aggregate_failures do
        result = service.check_health

        expect(result).to eq(unhealthy_response)
        expect(mock_github_client).to have_received(:health_check)
      end
    end

    context 'when github client raises an error' do
      before do
        allow(mock_github_client).to receive(:health_check).and_raise(StandardError, 'Connection failed')
      end

      it 'returns error response with proper format', :aggregate_failures do
        result = service.check_health

        expect(result).to include(
          status: 'unhealthy',
          error: 'Connection failed',
          service: 'GitHub Repository Fetcher',
          version: '1.0.0'
        )
        expect(result[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end

      it 'includes timestamp in ISO8601 format' do
        result = service.check_health

        expect(Time.parse(result[:timestamp])).to be_within(1).of(Time.now)
      end
    end

    context 'when github client raises different error types' do
      it 'handles RuntimeError' do
        allow(mock_github_client).to receive(:health_check).and_raise(RuntimeError, 'Runtime error')

        result = service.check_health

        expect(result[:error]).to eq('Runtime error')
      end

      it 'handles ArgumentError' do
        allow(mock_github_client).to receive(:health_check).and_raise(ArgumentError, 'Invalid argument')

        result = service.check_health

        expect(result[:error]).to eq('Invalid argument')
      end
    end
  end
end
