# frozen_string_literal: true

require "spec_helper"

RSpec.describe GithubRepoFetcher::GithubClient do
  let(:env_vars) do
    {
      "GITHUB_APP_ID" => "12345",
      "GITHUB_PRIVATE_KEY" => '-----BEGIN RSA PRIVATE KEY-----
MOCK_KEY_FOR_TESTING
-----END RSA PRIVATE KEY-----',
      "GITHUB_CLIENT_ID" => "Iv23li8mXIuQ2n1WXDLf",
      "GITHUB_CLIENT_SECRET" => "mock_secret"
    }
  end

  before do
    stub_const("ENV", env_vars)
  end

  describe "#initialize" do
    context "with valid environment variables" do
      before do
        stub_jwt_encode
        stub_rsa_new
        stub_installations_request
        stub_installation_access_token_request
      end

      it "initializes successfully" do
        expect { described_class.new }.not_to raise_error
      end
    end

    context "with missing environment variables" do
      before do
        stub_const("ENV", {})
      end

      it "raises an error" do
        expect { described_class.new }.to raise_error(/Missing required environment variables/)
      end
    end
  end

  describe "#rate_limit" do
    let(:client) { described_class.new }

    before do
      stub_jwt_encode
      stub_rsa_new
      stub_installations_request
      stub_installation_access_token_request
      stub_rate_limit_request
    end

    it "returns rate limit information", :aggregate_failures do
      result = client.rate_limit
      expect(result).to respond_to(:remaining)
      expect(result).to respond_to(:limit)
      expect(result).to respond_to(:resets_at)
    end

    context "when API is not accessible" do
      before do
        stub_rate_limit_error
      end

      it "raises an error" do
        expect { client.rate_limit }.to raise_error(/GitHub API error/)
      end
    end
  end

  describe "#fetch_user_projects" do
    let(:client) { described_class.new }

    before do
      stub_jwt_encode
      stub_rsa_new
      stub_installations_request
      stub_installation_access_token_request
    end

    it "returns an array of projects" do
      stub_repositories_request
      stub_languages_request

      projects = client.fetch_user_projects("testuser")
      expect(projects).to be_an(Array)
    end

    it "includes project metadata" do
      stub_repositories_request
      stub_languages_request

      projects = client.fetch_user_projects("testuser")
      project = projects.first
      expect(project).to include(:name, :description, :languages, :forks_count, :stargazers_count)
    end

    context "when the languages API returns no languages" do
      before do
        stub_repositories_request
        stub_languages_request(body: {})
      end

      it "falls back to file extensions from the git tree" do
        stub_tree_request([
          { path: "a.yml", type: "blob", size: 100 },
          { path: "b.yaml", type: "blob", size: 50 },
          { path: "README.md", type: "blob", size: 25 },
          { path: "logo.png", type: "blob", size: 999 },
          { path: "docs", type: "tree" }
        ])

        languages = client.fetch_user_projects("testuser").first[:languages]
        expect(languages).to eq("YAML" => 150, "Markdown" => 25)
      end

      it "returns an empty hash when no extensions match" do
        stub_tree_request([{ path: "logo.png", type: "blob", size: 10 }])

        expect(client.fetch_user_projects("testuser").first[:languages]).to eq({})
      end
    end

    context "when the languages API returns languages" do
      it "does not read the git tree" do
        stub_repositories_request
        stub_languages_request

        client.fetch_user_projects("testuser")
        expect(a_request(:get, %r{git/trees})).not_to have_been_made
      end
    end

    context "with fork metadata" do
      it "omits fork fields and makes no parent lookup by default", :aggregate_failures do
        stub_repositories_request(fork: true)
        stub_languages_request

        project = client.fetch_user_projects("testuser").first
        expect(project).not_to include(:fork, :parent_full_name)
        expect(a_request(:get, "https://api.github.com/repos/testuser/test-repo")).not_to have_been_made
      end

      it "marks a non-fork with no parent and makes no parent lookup", :aggregate_failures do
        stub_repositories_request
        stub_languages_request

        project = client.fetch_user_projects("testuser", include_fork_metadata: true).first
        expect(project).to include(fork: false, parent_full_name: nil)
        expect(a_request(:get, "https://api.github.com/repos/testuser/test-repo")).not_to have_been_made
      end

      it "returns the parent full_name for a fork" do
        stub_repositories_request(fork: true)
        stub_languages_request
        stub_repo_request(parent_full_name: "upstream/test-repo")
        stub_pull_request_search([])

        project = client.fetch_user_projects("testuser", include_fork_metadata: true).first
        expect(project).to include(fork: true, parent_full_name: "upstream/test-repo")
      end

      # rubocop:disable-next RSpec/ExampleLength
      it "returns a nil parent without failing the fetch when the parent lookup errors", :aggregate_failures do
        stub_repositories_request(fork: true)
        stub_languages_request
        stub_repo_error

        projects = client.fetch_user_projects("testuser", include_fork_metadata: true)
        expect(projects.size).to eq(1)
        expect(projects.first).to include(fork: true, parent_full_name: nil)
      end

      it "lists the user's pull requests into the parent with their state", :aggregate_failures do
        stub_repositories_request(fork: true)
        stub_languages_request
        stub_repo_request(parent_full_name: "upstream/test-repo")
        stub_pull_request_search(
          [
            pull_request_item(number: 1, title: "Merged fix", merged: true),
            pull_request_item(number: 2, title: "Open idea"),
            pull_request_item(number: 3, title: "Dropped", state: "closed")
          ],
          total_count: 4
        )

        project = client.fetch_user_projects("testuser", include_fork_metadata: true).first
        expect(project[:pull_requests]).to eq(
          [
            { title: "Merged fix", html_url: "https://github.com/upstream/test-repo/pull/1", state: "merged" },
            { title: "Open idea", html_url: "https://github.com/upstream/test-repo/pull/2", state: "open" },
            { title: "Dropped", html_url: "https://github.com/upstream/test-repo/pull/3", state: "closed" }
          ]
        )
        expect(project[:pull_requests_total]).to eq(4)
        expect(a_request(:get, "https://api.github.com/search/issues")
          .with(query: hash_including("q" => "repo:upstream/test-repo is:pr author:testuser"))).to have_been_made
      end

      it "leaves out pull request data when the search errors, keeping the fork fields" do
        stub_repositories_request(fork: true)
        stub_languages_request
        stub_repo_request(parent_full_name: "upstream/test-repo")
        stub_request(:get, %r{https://api\.github\.com/search/issues}).to_return(status: 500)

        project = client.fetch_user_projects("testuser", include_fork_metadata: true).first
        expect(project).to include(fork: true, parent_full_name: "upstream/test-repo")
        expect(project).not_to include(:pull_requests, :pull_requests_total)
      end

      it "makes no pull request search for a non-fork" do
        stub_repositories_request
        stub_languages_request

        client.fetch_user_projects("testuser", include_fork_metadata: true)
        expect(a_request(:get, %r{/search/issues})).not_to have_been_made
      end
    end

    context "when user is not found" do
      before do
        stub_user_not_found
      end

      it "raises an appropriate error" do
        expect { client.fetch_user_projects("nonexistent") }.to raise_error("User 'nonexistent' not found")
      end
    end

    context "when rate limit is exceeded" do
      before do
        stub_rate_limit_exceeded
      end

      it "raises an appropriate error" do
        expect do
          client.fetch_user_projects("testuser")
        end.to raise_error(
          "GitHub API error: GET https://api.github.com/users/testuser/repos?per_page=100: " \
          "429 - API rate limit exceeded"
        )
      end
    end
  end

  private

  def stub_jwt_encode
    allow(JWT).to receive(:encode).and_return("mock_jwt_token")
  end

  def stub_rsa_new
    mock_rsa = instance_double(OpenSSL::PKey::RSA)
    allow(OpenSSL::PKey::RSA).to receive(:new).and_return(mock_rsa)
  end

  def stub_installations_request
    stub_request(:get, "https://api.github.com/app/installations")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "Bearer mock_jwt_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [{ id: 12_345 }].to_json
      )
  end

  def stub_installation_access_token_request
    stub_request(:post, "https://api.github.com/app/installations/12345/access_tokens")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "Bearer mock_jwt_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: { token: "ghs_mock_token" }.to_json
      )
  end

  def stub_rate_limit_request
    stub_request(:get, "https://api.github.com/rate_limit")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "token ghs_mock_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
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
    stub_request(:get, "https://api.github.com/rate_limit")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "token ghs_mock_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(status: 500)
  end

  def stub_repositories_request(fork: false)
    stub_request(:get, "https://api.github.com/users/testuser/repos?per_page=100")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "token ghs_mock_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          {
            name: "test-repo",
            description: "A test repository",
            full_name: "testuser/test-repo",
            default_branch: "main",
            forks_count: 5,
            stargazers_count: 10,
            fork: fork,
            html_url: "https://github.com/testuser/test-repo",
            created_at: "2023-01-01T00:00:00Z",
            updated_at: "2023-12-01T00:00:00Z"
          }
        ].to_json
      )
  end

  def stub_tree_request(entries)
    stub_request(:get, "https://api.github.com/repos/testuser/test-repo/git/trees/main?recursive=true")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { sha: "abc", tree: entries, truncated: false }.to_json
      )
  end

  def stub_languages_request(body: { Ruby: 1000, JavaScript: 500 })
    stub_request(:get, "https://api.github.com/repos/testuser/test-repo/languages")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "token ghs_mock_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: body.to_json
      )
  end

  def stub_repo_request(parent_full_name:)
    stub_request(:get, "https://api.github.com/repos/testuser/test-repo")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          name: "test-repo",
          full_name: "testuser/test-repo",
          fork: true,
          parent: { full_name: parent_full_name }
        }.to_json
      )
  end

  def stub_repo_error
    stub_request(:get, "https://api.github.com/repos/testuser/test-repo")
      .to_return(status: 500)
  end

  def stub_pull_request_search(items, total_count: items.size)
    stub_request(:get, %r{https://api\.github\.com/search/issues})
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { total_count: total_count, incomplete_results: false, items: items }.to_json
      )
  end

  def pull_request_item(number:, title:, merged: false, state: "open")
    {
      title: title,
      html_url: "https://github.com/upstream/test-repo/pull/#{number}",
      state: state,
      pull_request: { merged_at: merged ? "2026-01-02T00:00:00Z" : nil }
    }
  end

  def stub_user_not_found
    stub_request(:get, "https://api.github.com/users/nonexistent/repos?per_page=100")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "token ghs_mock_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(status: 404)
  end

  def stub_rate_limit_exceeded
    stub_request(:get, "https://api.github.com/users/testuser/repos?per_page=100")
      .with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "token ghs_mock_token",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 429,
        headers: {
          "Content-Type" => "application/json",
          "X-RateLimit-Limit" => "5000",
          "X-RateLimit-Remaining" => "0",
          "X-RateLimit-Reset" => (Time.now + 3600).to_i.to_s
        },
        body: { message: "API rate limit exceeded" }.to_json
      )
  end
end
