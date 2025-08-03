# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitHubRepoFetcher do
  describe 'module' do
    it 'is defined' do
      expect(described_class).to be_a(Module)
    end

    it 'has GitHubClient class' do
      expect(GitHubRepoFetcher::GitHubClient).to be_a(Class)
    end
  end

  describe GitHubRepoFetcher::GitHubClient do
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

    describe '#new' do
      it 'can be instantiated' do
        expect { described_class.new }.not_to raise_error
      end
    end
  end
end
