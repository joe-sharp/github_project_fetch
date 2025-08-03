# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitHubRepoFetcher::GitHubClient do
  describe '#initialize' do
    context 'with valid environment variables' do
      before do
        stub_const('ENV', {
                     'GITHUB_APP_ID' => '12345',
                     'GITHUB_PRIVATE_KEY' => '-----BEGIN RSA PRIVATE KEY-----\nMOCK_KEY\n-----END RSA PRIVATE KEY-----',
                     'GITHUB_CLIENT_ID' => 'Iv23li8mXIuQ2n1WXDLf',
                     'GITHUB_CLIENT_SECRET' => 'mock_secret'
                   })
        allow_any_instance_of(described_class).to receive(:generate_jwt_token).and_return('mock_jwt_token')
        allow_any_instance_of(described_class).to receive(:setup_installation_client)
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

  describe '#health_check' do
    let(:client) { described_class.new }
    let(:mock_octokit_client) { instance_double(Octokit::Client) }
    let(:mock_rate_limit) do
      double(
        'rate_limit',
        remaining: 4999,
        limit: 5000,
        resets_at: Time.now.to_i + 3600
      )
    end

    before do
      stub_const('ENV', {
                   'GITHUB_APP_ID' => '12345',
                   'GITHUB_PRIVATE_KEY' => '-----BEGIN RSA PRIVATE KEY-----\nMOCK_KEY\n-----END RSA PRIVATE KEY-----',
                   'GITHUB_CLIENT_ID' => 'Iv23li8mXIuQ2n1WXDLf',
                   'GITHUB_CLIENT_SECRET' => 'mock_secret'
                 })
      allow_any_instance_of(described_class).to receive(:generate_jwt_token).and_return('mock_jwt_token')
      allow_any_instance_of(described_class).to receive(:setup_installation_client)
      allow(Octokit::Client).to receive(:new).and_return(mock_octokit_client)
      allow(mock_octokit_client).to receive(:rate_limit).and_return(mock_rate_limit)
    end

    it 'returns healthy status with rate limit information', :aggregate_failures do
      result = client.health_check
      expect(result[:status]).to eq('healthy')
      expect(result[:message]).to eq('GitHub API connection successful')
      expect(result[:rate_limit]).to include(
        remaining: 4999,
        limit: 5000,
        used_percentage: 0.02
      )
      expect(result[:rate_limit][:reset_time]).to be_a(String)
    end

    context 'when API is not accessible' do
      before do
        allow(mock_octokit_client).to receive(:rate_limit).and_raise(Octokit::Error.new(message: 'API Error'))
      end

      it 'returns unhealthy status' do
        result = client.health_check
        expect(result[:status]).to eq('unhealthy')
        expect(result[:message]).to include('GitHub API error')
      end
    end
  end

  describe '#fetch_user_repositories', :aggregate_failures do
    let(:client) { described_class.new }
    let(:mock_octokit_client) { instance_double(Octokit::Client) }
    let(:mock_repo) do
      double(
        'repo',
        name: 'test-repo',
        description: 'A test repository',
        full_name: 'testuser/test-repo',
        forks_count: 5,
        stargazers_count: 10,
        html_url: 'https://github.com/testuser/test-repo',
        created_at: Time.new(2023, 1, 1),
        updated_at: Time.new(2023, 12, 1)
      )
    end

    before do
      stub_const('ENV', {
                   'GITHUB_APP_ID' => '12345',
                   'GITHUB_PRIVATE_KEY' => '-----BEGIN RSA PRIVATE KEY-----\nMOCK_KEY\n-----END RSA PRIVATE KEY-----',
                   'GITHUB_CLIENT_ID' => 'Iv23li8mXIuQ2n1WXDLf',
                   'GITHUB_CLIENT_SECRET' => 'mock_secret'
                 })
      allow_any_instance_of(described_class).to receive(:generate_jwt_token).and_return('mock_jwt_token')
      allow_any_instance_of(described_class).to receive(:setup_installation_client)
      allow(Octokit::Client).to receive(:new).and_return(mock_octokit_client)
      allow(mock_octokit_client).to receive(:repos).with('testuser', per_page: 100).and_return([mock_repo])
      allow(mock_octokit_client).to receive(:languages).with('testuser/test-repo').and_return({ 'Ruby' => 1000,
                                                                                                'JavaScript' => 500 })
    end

    it 'fetches repositories successfully' do
      repos = client.fetch_user_repositories('testuser')

      expect(repos).to be_an(Array)
      expect(repos.length).to eq(1)

      repo = repos.first
      expect(repo[:name]).to eq('test-repo')
      expect(repo[:description]).to eq('A test repository')
      expect(repo[:forks_count]).to eq(5)
      expect(repo[:stargazers_count]).to eq(10)
      expect(repo[:languages]).to eq({ 'Ruby' => 1000, 'JavaScript' => 500 })
    end

    it 'caches repository data' do
      # First call should hit the API
      expect(mock_octokit_client).to receive(:repos).with('testuser', per_page: 100).once.and_return([mock_repo])
      expect(mock_octokit_client).to receive(:languages).with('testuser/test-repo').once.and_return({ 'Ruby' => 1000,
                                                                                                      'JavaScript' => 500 })

      client.fetch_user_repositories('testuser')

      # Second call should use cache
      repos = client.fetch_user_repositories('testuser')
      expect(repos).to be_an(Array)
      expect(repos.length).to eq(1)
    end

    context 'when user is not found' do
      before do
        allow(mock_octokit_client).to receive(:repos).and_raise(Octokit::NotFound.new)
      end

      it 'raises an appropriate error' do
        expect { client.fetch_user_repositories('nonexistent') }.to raise_error("User 'nonexistent' not found")
      end
    end

    context 'when rate limit is exceeded' do
      before do
        allow(mock_octokit_client).to receive(:repos).and_raise(Octokit::TooManyRequests.new)
      end

      it 'raises an appropriate error' do
        expect do
          client.fetch_user_repositories('testuser')
        end.to raise_error('GitHub API rate limit exceeded. Please try again later.')
      end
    end

    context 'when languages cannot be fetched' do
      before do
        allow(mock_octokit_client).to receive(:languages).and_raise(Octokit::Error.new(message: 'Language fetch failed'))
      end

      it 'returns empty languages hash' do
        repos = client.fetch_user_repositories('testuser')
        expect(repos.first[:languages]).to eq({})
      end
    end
  end

  describe 'WebMock integration' do
    let(:client) { described_class.new }

    before do
      stub_const('ENV', {
                   'GITHUB_APP_ID' => '12345',
                   'GITHUB_PRIVATE_KEY' => '-----BEGIN RSA PRIVATE KEY-----\nMOCK_KEY\n-----END RSA PRIVATE KEY-----',
                   'GITHUB_CLIENT_ID' => 'Iv23li8mXIuQ2n1WXDLf',
                   'GITHUB_CLIENT_SECRET' => 'mock_secret'
                 })
      allow_any_instance_of(described_class).to receive(:generate_jwt_token).and_return('mock_jwt_token')
      allow_any_instance_of(described_class).to receive(:setup_installation_client)
    end

    it 'blocks external HTTP requests' do
      expect { Net::HTTP.get(URI('https://api.github.com/users/test')) }.to raise_error(WebMock::NetConnectNotAllowedError)
    end

    it 'allows localhost requests when stubbed' do
      stub_request(:get, 'http://localhost:3000/test').to_return(status: 200, body: 'OK')

      response = Net::HTTP.get(URI('http://localhost:3000/test'))
      expect(response).to eq('OK')
    end
  end
end
