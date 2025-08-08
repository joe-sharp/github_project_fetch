# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GithubRepoFetcher::ProjectService do
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

  describe '#fetch_user_projects' do
    let(:mock_projects) do
      [
        {
          name: 'test-repo',
          description: 'A test repository',
          languages: { 'Ruby' => 1000, 'JavaScript' => 500 },
          forks_count: 5,
          stargazers_count: 10,
          html_url: 'https://github.com/testuser/test-repo',
          created_at: '2023-01-01T00:00:00Z',
          updated_at: '2023-01-02T00:00:00Z'
        }
      ]
    end

    context 'with valid username' do
      before do
        allow(mock_github_client).to receive(:fetch_user_projects).with('testuser').and_return(mock_projects)
      end

      it 'returns formatted project data' do
        result = service.fetch_user_projects('testuser')

        expect(result).to include(
          username: 'testuser',
          projects_count: 1,
          projects: mock_projects
        )
      end

      it 'sanitizes username correctly', :aggregate_failures do
        result = service.fetch_user_projects('TestUser!@#')

        expect(result[:username]).to eq('testuser')
        expect(mock_github_client).to have_received(:fetch_user_projects).with('testuser')
      end

      it 'handles username with special characters', :aggregate_failures do
        allow(mock_github_client).to receive(:fetch_user_projects).with('test-user_123').and_return(mock_projects)

        result = service.fetch_user_projects('test-user_123')

        expect(result[:username]).to eq('test-user_123')
        expect(mock_github_client).to have_received(:fetch_user_projects).with('test-user_123')
      end

      it 'truncates long usernames to 39 characters', :aggregate_failures do
        long_username = 'a' * 50
        allow(mock_github_client).to receive(:fetch_user_projects).with('a' * 39).and_return(mock_projects)

        result = service.fetch_user_projects(long_username)

        expect(result[:username].length).to eq(39)
        expect(mock_github_client).to have_received(:fetch_user_projects).with('a' * 39)
      end
    end

    context 'with invalid username' do
      it 'handles nil username gracefully', :aggregate_failures do
        allow(mock_github_client).to receive(:fetch_user_projects).with(nil).and_return(mock_projects)
        result = service.fetch_user_projects(nil)
        expect(result[:username]).to be_nil
        expect(mock_github_client).to have_received(:fetch_user_projects).with(nil)
      end

      it 'handles empty username gracefully', :aggregate_failures do
        allow(mock_github_client).to receive(:fetch_user_projects).with(nil).and_return(mock_projects)
        result = service.fetch_user_projects('')
        expect(result[:username]).to be_nil
        expect(mock_github_client).to have_received(:fetch_user_projects).with(nil)
      end

      it 'handles whitespace-only username gracefully', :aggregate_failures do
        allow(mock_github_client).to receive(:fetch_user_projects).with('').and_return(mock_projects)
        result = service.fetch_user_projects('   ')
        expect(result[:username]).to eq('')
        expect(mock_github_client).to have_received(:fetch_user_projects).with('')
      end
    end

    context 'when github client raises an error' do
      before do
        allow(mock_github_client).to receive(:fetch_user_projects).and_raise(StandardError, 'GitHub API error')
      end

      it 'propagates the error' do
        expect { service.fetch_user_projects('testuser') }.to raise_error(StandardError, 'GitHub API error')
      end
    end
  end

  describe 'private methods' do
    describe '#sanitize_username' do
      it 'returns nil for nil input' do
        result = service.send(:sanitize_username, nil)
        expect(result).to be_nil
      end

      it 'returns nil for empty input' do
        result = service.send(:sanitize_username, '')
        expect(result).to be_nil
      end

      it 'converts to lowercase' do
        result = service.send(:sanitize_username, 'TestUser')
        expect(result).to eq('testuser')
      end

      it 'removes special characters' do
        result = service.send(:sanitize_username, 'test@user!')
        expect(result).to eq('testuser')
      end

      it 'preserves hyphens and underscores' do
        result = service.send(:sanitize_username, 'test-user_123')
        expect(result).to eq('test-user_123')
      end

      it 'truncates to 39 characters', :aggregate_failures do
        long_username = 'a' * 50
        result = service.send(:sanitize_username, long_username)
        expect(result.length).to eq(39)
        expect(result).to eq('a' * 39)
      end
    end
  end
end
