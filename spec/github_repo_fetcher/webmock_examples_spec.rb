# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'WebMock GitHub API Examples' do
  describe 'GitHub API stubbing examples' do
    before do
      stub_const('ENV', {
                   'GITHUB_APP_ID' => '12345',
                   'GITHUB_PRIVATE_KEY' => '-----BEGIN RSA PRIVATE KEY-----\nMOCK_KEY\n-----END RSA PRIVATE KEY-----',
                   'GITHUB_CLIENT_ID' => 'Iv23li8mXIuQ2n1WXDLf',
                   'GITHUB_CLIENT_SECRET' => 'mock_secret'
                 })
      allow_any_instance_of(GitHubRepoFetcher::GitHubClient).to receive(:generate_jwt_token).and_return('mock_jwt_token')
      allow_any_instance_of(GitHubRepoFetcher::GitHubClient).to receive(:setup_installation_client)
    end

    it 'demonstrates stubbing GitHub API rate limit endpoint' do
      # Stub the rate limit endpoint with the correct response structure
      stub_request(:get, 'https://api.github.com/rate_limit')
        .with(headers: { 'Authorization' => 'Bearer mock_jwt_token' })
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            resources: {
              core: {
                limit: 5000,
                remaining: 1,
                reset: Time.now.to_i + 3600
              }
            }
          }.to_json
        )

      client = GitHubRepoFetcher::GitHubClient.new
      result = client.health_check

      expect(result[:status]).to eq('healthy')
      expect(result[:rate_limit][:remaining]).to eq(1)
    end

    it 'demonstrates stubbing GitHub repositories endpoint' do
      # Stub the repositories endpoint
      stub_request(:get, 'https://api.github.com/users/testuser/repos?per_page=100')
        .with(headers: { 'Authorization' => 'Bearer mock_jwt_token' })
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

      # Stub the languages endpoint with symbols (as returned by Octokit)
      stub_request(:get, 'https://api.github.com/repos/testuser/test-repo/languages')
        .with(headers: { 'Authorization' => 'Bearer mock_jwt_token' })
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            Ruby: 1000,
            JavaScript: 500
          }.to_json
        )

      client = GitHubRepoFetcher::GitHubClient.new
      repos = client.fetch_user_repositories('testuser')

      expect(repos).to be_an(Array)
      expect(repos.length).to eq(1)
      expect(repos.first[:name]).to eq('test-repo')
      expect(repos.first[:languages][:Ruby]).to eq(1000)
      expect(repos.first[:languages][:JavaScript]).to eq(500)
    end

    it 'demonstrates stubbing GitHub API errors' do
      # Stub a 404 error for user not found
      stub_request(:get, 'https://api.github.com/users/nonexistent/repos?per_page=100')
        .with(headers: { 'Authorization' => 'Bearer mock_jwt_token' })
        .to_return(
          status: 404,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            message: 'Not Found',
            documentation_url: 'https://docs.github.com/rest'
          }.to_json
        )

      client = GitHubRepoFetcher::GitHubClient.new

      expect { client.fetch_user_repositories('nonexistent') }.to raise_error("User 'nonexistent' not found")
    end

    it 'demonstrates stubbing rate limit exceeded error' do
      # Stub a 403 rate limit error
      stub_request(:get, 'https://api.github.com/users/testuser/repos?per_page=100')
        .with(headers: { 'Authorization' => 'Bearer mock_jwt_token' })
        .to_return(
          status: 403,
          headers: {
            'Content-Type' => 'application/json',
            'X-RateLimit-Remaining' => '0',
            'X-RateLimit-Reset' => (Time.now.to_i + 3600).to_s
          },
          body: {
            message: 'API rate limit exceeded',
            documentation_url: 'https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting'
          }.to_json
        )

      client = GitHubRepoFetcher::GitHubClient.new

      expect do
        client.fetch_user_repositories('testuser')
      end.to raise_error('GitHub API rate limit exceeded. Please try again later.')
    end

    it 'demonstrates stubbing installation endpoints' do
      # Stub the app installations endpoint
      stub_request(:get, 'https://api.github.com/app/installations')
        .with(headers: { 'Authorization' => 'Bearer mock_jwt_token' })
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: [
            {
              id: 12_345,
              account: {
                login: 'testuser',
                type: 'User'
              },
              permissions: {
                contents: 'read',
                metadata: 'read'
              }
            }
          ].to_json
        )

      # Stub the installation access token endpoint
      stub_request(:post, 'https://api.github.com/app/installations/12345/access_tokens')
        .with(headers: { 'Authorization' => 'Bearer mock_jwt_token' })
        .to_return(
          status: 201,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            token: 'ghs_mock_installation_token',
            expires_at: (Time.now + 3600).iso8601,
            permissions: {
              contents: 'read',
              metadata: 'read'
            }
          }.to_json
        )

      # This should not raise an error during setup
      expect { GitHubRepoFetcher::GitHubClient.new }.not_to raise_error
    end
  end
end
