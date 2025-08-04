# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GithubRepoFetcher::HealthService do
  subject(:service) { described_class.new(github_client) }

  let(:github_client) { instance_double(GithubRepoFetcher::GithubClient) }
  let(:rate_limit_info) { instance_double(Octokit::RateLimit) }
  let(:reset_time) { Time.parse('2023-01-01T12:00:00Z').utc }

  describe '#initialize' do
    context 'with provided github client' do
      it 'creates a new instance' do
        expect(described_class.new(github_client)).to be_a(described_class)
      end
    end

    context 'without github client' do
      before do
        stub_github_app_authentication
      end

      it 'creates a new instance with default client' do
        expect(described_class.new).to be_a(described_class)
      end
    end
  end

  describe '#check_health' do
    context 'when github client returns rate limit info successfully' do
      before do
        allow(rate_limit_info).to receive_messages(
          remaining: 4000,
          limit: 5000,
          resets_at: reset_time.to_i
        )
        allow(github_client).to receive(:rate_limit).and_return(rate_limit_info)
      end

      it 'returns healthy status' do
        result = service.check_health

        expect(result[:status]).to eq('healthy')
      end

      it 'returns correct message and metadata' do
        result = service.check_health

        expect(result).to include(
          message: 'GitHub API connection successful',
          service: 'GitHub Repository Fetcher',
          version: '1.0.0'
        )
      end

      it 'includes timestamp in correct format' do
        result = service.check_health

        expect(result[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end

      it 'includes correct rate limit data', :aggregate_failures do
        result = service.check_health

        expect(result[:rate_limit]).to include(
          remaining: 4000,
          limit: 5000,
          used_percentage: 20.0
        )
        expect(result[:rate_limit][:reset_time]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      it 'calculates used percentage correctly for zero remaining' do
        allow(rate_limit_info).to receive_messages(remaining: 0, limit: 5000)

        result = service.check_health

        expect(result[:rate_limit][:used_percentage]).to eq(100.0)
      end

      it 'calculates used percentage correctly for half remaining' do
        allow(rate_limit_info).to receive_messages(remaining: 2500, limit: 5000)

        result = service.check_health

        expect(result[:rate_limit][:used_percentage]).to eq(50.0)
      end
    end

    context 'when github client raises an error' do
      let(:error_message) do
        'GitHub API error: GET https://api.github.com/rate_limit: 500 - Internal Server Error'
      end

      before do
        allow(github_client).to receive(:rate_limit).and_raise(StandardError.new(error_message))
      end

      it 'returns unhealthy status' do
        result = service.check_health

        expect(result[:status]).to eq('unhealthy')
      end

      it 'includes error message and metadata' do
        result = service.check_health

        expect(result).to include(
          error: error_message,
          service: 'GitHub Repository Fetcher',
          version: '1.0.0'
        )
      end

      it 'includes timestamp in ISO8601 format' do
        result = service.check_health

        expect(Time.parse(result[:timestamp])).to be_within(1).of(Time.now)
      end
    end

    context 'when github client raises different error types' do
      it 'handles network timeout' do
        allow(github_client).to receive(:rate_limit).and_raise(Net::ReadTimeout.new('execution expired'))

        result = service.check_health

        expect(result[:status]).to eq('unhealthy')
      end

      it 'handles network timeout error message' do
        allow(github_client).to receive(:rate_limit).and_raise(Net::ReadTimeout.new('execution expired'))

        result = service.check_health

        expect(result[:error]).to include('execution expired')
      end

      it 'handles connection refused' do
        error = Errno::ECONNREFUSED.new('Connection refused')
        allow(github_client).to receive(:rate_limit).and_raise(error)

        result = service.check_health

        expect(result[:status]).to eq('unhealthy')
      end

      it 'handles connection refused error message' do
        error = Errno::ECONNREFUSED.new('Connection refused')
        allow(github_client).to receive(:rate_limit).and_raise(error)

        result = service.check_health

        expect(result[:error]).to include('Connection refused')
      end
    end
  end

  private

  def stub_github_app_authentication
    env_vars = {
      'GITHUB_APP_ID' => '12345',
      'GITHUB_PRIVATE_KEY' => test_private_key,
      'GITHUB_CLIENT_ID' => 'Iv23li8mXIuQ2n1WXDLf',
      'GITHUB_CLIENT_SECRET' => 'mock_secret'
    }
    stub_const('ENV', env_vars)

    stub_jwt_and_rsa
    stub_github_api_calls
  end

  def stub_jwt_and_rsa
    allow(JWT).to receive(:encode).and_return('mock_jwt_token')
    mock_rsa = instance_double(OpenSSL::PKey::RSA)
    allow(OpenSSL::PKey::RSA).to receive(:new).and_return(mock_rsa)
  end

  def stub_github_api_calls
    stub_request(:get, 'https://api.github.com/app/installations')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: [{ id: 123_456 }].to_json
      )

    stub_request(:post, 'https://api.github.com/app/installations/123456/access_tokens')
      .to_return(
        status: 201,
        headers: { 'Content-Type' => 'application/json' },
        body: { token: 'gho_test_token_123' }.to_json
      )
  end

  def test_private_key
    <<~PRIVATE_KEY
      -----BEGIN RSA PRIVATE KEY-----
      MOCK_KEY_FOR_TESTING
      -----END RSA PRIVATE KEY-----
    PRIVATE_KEY
  end
end
