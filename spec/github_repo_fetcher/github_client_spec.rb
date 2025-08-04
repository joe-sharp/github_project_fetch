# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GithubRepoFetcher::GithubClient do
  let(:env_vars) do
    {
      'GITHUB_APP_ID' => '12345',
      'GITHUB_PRIVATE_KEY' => '-----BEGIN RSA PRIVATE KEY-----
MOCK_KEY_FOR_TESTING
-----END RSA PRIVATE KEY-----',
      'GITHUB_CLIENT_ID' => 'Iv23li8mXIuQ2n1WXDLf',
      'GITHUB_CLIENT_SECRET' => 'mock_secret'
    }
  end

  before do
    stub_const('ENV', env_vars)
  end

  describe '#initialize' do
    context 'with valid environment variables' do
      before do
        stub_jwt_encode
        stub_rsa_new
        stub_installations_request
        stub_installation_access_token_request
      end

      it 'initializes successfully' do
        expect { described_class.new }.not_to raise_error
      end
    end

    context 'with missing environment variables' do
      before do
        stub_const('ENV', {})
      end

      it 'raises an error' do
        expect { described_class.new }.to raise_error(/Missing required environment variables/)
      end
    end
  end

  describe '#rate_limit' do
    let(:client) { described_class.new }

    before do
      stub_jwt_encode
      stub_rsa_new
      stub_installations_request
      stub_installation_access_token_request
      stub_rate_limit_request
    end

    it 'returns rate limit information', :aggregate_failures do
      result = client.rate_limit
      expect(result).to respond_to(:remaining)
      expect(result).to respond_to(:limit)
      expect(result).to respond_to(:resets_at)
    end

    context 'when API is not accessible' do
      before do
        stub_rate_limit_error
      end

      it 'raises an error' do
        expect { client.rate_limit }.to raise_error(/GitHub API error/)
      end
    end
  end

  describe '#fetch_user_projects' do
    let(:client) { described_class.new }

    before do
      stub_jwt_encode
      stub_rsa_new
      stub_installations_request
      stub_installation_access_token_request
    end

    it 'returns an array of projects' do
      stub_repositories_request
      stub_languages_request

      projects = client.fetch_user_projects('testuser')
      expect(projects).to be_an(Array)
    end

    it 'includes project metadata' do
      stub_repositories_request
      stub_languages_request

      projects = client.fetch_user_projects('testuser')
      project = projects.first
      expect(project).to include(:name, :description, :languages, :forks_count, :stargazers_count)
    end

    context 'when user is not found' do
      before do
        stub_user_not_found
      end

      it 'raises an appropriate error' do
        expect { client.fetch_user_projects('nonexistent') }.to raise_error("User 'nonexistent' not found")
      end
    end

    context 'when rate limit is exceeded' do
      before do
        stub_rate_limit_exceeded
      end

      it 'raises an appropriate error' do
        expect do
          client.fetch_user_projects('testuser')
        end.to raise_error(
          'GitHub API error: GET https://api.github.com/users/testuser/repos?per_page=100: ' \
          '429 - API rate limit exceeded'
        )
      end
    end
  end

  private

  def stub_jwt_encode
    allow(JWT).to receive(:encode).and_return('mock_jwt_token')
  end

  def stub_rsa_new
    mock_rsa = instance_double(OpenSSL::PKey::RSA)
    allow(OpenSSL::PKey::RSA).to receive(:new).and_return(mock_rsa)
  end

  def stub_installations_request
    stub_request(:get, 'https://api.github.com/app/installations')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'Bearer mock_jwt_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: [{ id: 12_345 }].to_json
      )
  end

  def stub_installation_access_token_request
    stub_request(:post, 'https://api.github.com/app/installations/12345/access_tokens')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'Bearer mock_jwt_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 201,
        headers: { 'Content-Type' => 'application/json' },
        body: { token: 'ghs_mock_token' }.to_json
      )
  end

  def stub_rate_limit_request
    stub_request(:get, 'https://api.github.com/rate_limit')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'token ghs_mock_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          resources: {
            core: {
              limit: 5000,
              remaining: 4999,
              reset: Time.now.to_i + 3600
            }
          }
        }.to_json
      )
  end

  def stub_rate_limit_error
    stub_request(:get, 'https://api.github.com/rate_limit')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'token ghs_mock_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(status: 500)
  end

  def stub_repositories_request
    stub_request(:get, 'https://api.github.com/users/testuser/repos?per_page=100')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'token ghs_mock_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: [
          {
            name: 'test-repo',
            description: 'A test repository',
            full_name: 'testuser/test-repo',
            forks_count: 5,
            stargazers_count: 10,
            html_url: 'https://github.com/testuser/test-repo',
            created_at: '2023-01-01T00:00:00Z',
            updated_at: '2023-12-01T00:00:00Z'
          }
        ].to_json
      )
  end

  def stub_languages_request
    stub_request(:get, 'https://api.github.com/repos/testuser/test-repo/languages')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'token ghs_mock_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { Ruby: 1000, JavaScript: 500 }.to_json
      )
  end

  def stub_user_not_found
    stub_request(:get, 'https://api.github.com/users/nonexistent/repos?per_page=100')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'token ghs_mock_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(status: 404)
  end

  def stub_rate_limit_exceeded
    stub_request(:get, 'https://api.github.com/users/testuser/repos?per_page=100')
      .with(
        headers: {
          'Accept' => 'application/vnd.github.v3+json',
          'Authorization' => 'token ghs_mock_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 429,
        headers: {
          'Content-Type' => 'application/json',
          'X-RateLimit-Limit' => '5000',
          'X-RateLimit-Remaining' => '0',
          'X-RateLimit-Reset' => (Time.now + 3600).to_i.to_s
        },
        body: { message: 'API rate limit exceeded' }.to_json
      )
  end
end
