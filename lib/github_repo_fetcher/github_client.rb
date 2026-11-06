# frozen_string_literal: true

require "octokit"
require "jwt"
require_relative "language_fallback"

module GithubRepoFetcher
  # GithubClient handles authentication and interaction with the GitHub API
  # It provides methods to fetch repository data and check API health status
  # Uses JWT authentication for GitHub App integration and implements caching
  class GithubClient
    attr_reader :client

    def initialize
      @app_id = ENV.fetch("GITHUB_APP_ID", nil)
      @private_key = ENV.fetch("GITHUB_PRIVATE_KEY", nil)
      @client_id = ENV.fetch("GITHUB_CLIENT_ID", nil)
      @client_secret = ENV.fetch("GITHUB_CLIENT_SECRET", nil)
      @cache = {}
      @cache_ttl = 300 # 5 minutes cache

      validate_configuration
      setup_client
    end

    def fetch_user_projects(username, include_fork_metadata: false)
      cache_key = "projects_#{username}#{"_fork_metadata" if include_fork_metadata}"
      return @cache[cache_key][:data] if cache_valid?(cache_key)

      projects = fetch_and_transform_projects(username, include_fork_metadata)
      cache_projects(cache_key, projects)
      projects
    rescue Octokit::NotFound
      raise "User '#{username}' not found"
    rescue Octokit::TooManyRequests
      raise "GitHub API rate limit exceeded. Please try again later."
    rescue Octokit::Error => e
      raise "GitHub API error: #{e.message}"
    end

    def rate_limit
      client.rate_limit
    rescue Octokit::Error => e
      raise "GitHub API error: #{e.message}"
    end

    private

    def validate_configuration
      required_vars = %w[GITHUB_APP_ID GITHUB_PRIVATE_KEY GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET]
      missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }

      return if missing_vars.empty?

      raise "Missing required environment variables: #{missing_vars.join(", ")}"
    end

    def setup_client
      # Generate JWT token for GitHub App authentication
      jwt_token = generate_jwt_token

      # Create client with JWT authentication
      @client = Octokit::Client.new(
        bearer_token: jwt_token,
        client_id: @client_id,
        client_secret: @client_secret
      )

      # Try to get installation access token if app is installed
      setup_installation_client
    end

    def setup_installation_client
      installations = @client.find_app_installations
      return log_error("No installations found. Install the app to access projects.") unless installations.any?

      setup_client_with_installation(installations.first)
    rescue Octokit::Unauthorized => e
      log_error("Authentication failed during installation setup: #{e.message}")
    rescue Octokit::Error => e
      log_error("Could not set up installation client: #{e.message}")
    rescue => e
      log_error("Unexpected error during installation setup: #{e.message}")
    end

    def setup_client_with_installation(installation)
      installation_id = installation.id
      access_token = @client.create_app_installation_access_token(installation_id)
      create_installation_client(access_token.token)
    end

    def create_installation_client(token)
      @client = Octokit::Client.new(
        access_token: token,
        client_id: @client_id,
        client_secret: @client_secret
      )
    end

    def log_error(message)
      warn "⚠️  #{message}"
      # Continue with JWT client for basic app operations
    end

    def generate_jwt_token
      # JWT payload for GitHub App authentication
      payload = {
        iat: Time.now.to_i - 60,               # Issued at time (60 seconds in past for clock drift)
        exp: Time.now.to_i + (10 * 60),        # Expiration time (10 minutes)
        iss: @client_id                        # GitHub App Client ID (not App ID)
      }

      # Parse the private key into OpenSSL::PKey::RSA instance
      private_key_content = @private_key.gsub('\n', "\n")
      private_key = OpenSSL::PKey::RSA.new(private_key_content)

      # Generate JWT token
      JWT.encode(payload, private_key, "RS256")
    rescue JWT::EncodeError => e
      raise "Failed to generate JWT token: #{e.message}"
    rescue OpenSSL::PKey::RSAError => e
      raise "Failed to parse private key: #{e.message}"
    end

    def fetch_repository_languages(full_name, default_branch = nil)
      cache_key = "languages_#{full_name}"
      return @cache[cache_key][:data] if cache_valid?(cache_key)

      # Convert Sawyer::Resource to hash for JSON serialization
      languages_hash = client.languages(full_name).to_h
      languages_hash = LanguageFallback.fetch(client, full_name, default_branch) if languages_hash.empty?

      # Cache the results
      @cache[cache_key] = { data: languages_hash, timestamp: Time.now }

      languages_hash
    rescue Octokit::Error
      # Return empty hash if languages can't be fetched
      {}
    end

    def cache_valid?(key)
      return false unless @cache[key]

      (Time.now - @cache[key][:timestamp]) < @cache_ttl
    end

    def fetch_and_transform_projects(username, include_fork_metadata)
      client.repos(username, per_page: 100).map do |repo|
        transform_project_data(repo, username, include_fork_metadata)
      end
    end

    def transform_project_data(repo, username, include_fork_metadata)
      {
        name: repo.name,
        description: repo.description,
        languages: fetch_repository_languages(repo.full_name, repo.default_branch),
        forks_count: repo.forks_count,
        stargazers_count: repo.stargazers_count,
        **fork_metadata(repo, username, include_fork_metadata),
        html_url: repo.html_url,
        created_at: repo.created_at,
        updated_at: repo.updated_at
      }
    end

    def fork_metadata(repo, username, include_fork_metadata)
      return {} unless include_fork_metadata

      parent_name = fork_parent_full_name(repo)
      metadata = { fork: repo.fork, parent_full_name: parent_name }
      return metadata unless parent_name

      metadata.merge(fork_pull_requests(parent_name, username) || {})
    end

    # The user's pull requests into the parent repo, newest first. Returns nil
    # when the search fails, so the fetch still succeeds without PR data.
    def fork_pull_requests(parent_name, username)
      cache_key = "pull_requests_#{parent_name}_#{username}"
      return @cache[cache_key][:data] if cache_valid?(cache_key)

      results = client.search_issues("repo:#{parent_name} is:pr author:#{username}",
                                     per_page: 100, sort: "created", order: "desc")
      data = {
        pull_requests: results.items.map { |item| pull_request_summary(item) },
        pull_requests_total: results.total_count
      }
      @cache[cache_key] = { data: data, timestamp: Time.now }
      data
    rescue Octokit::Error
      nil
    end

    def pull_request_summary(item)
      state = item.pull_request&.merged_at ? "merged" : item.state
      { title: item.title, html_url: item.html_url, state: state }
    end

    # The list endpoint omits `parent`, so a fork needs its own repo lookup.
    # Returns nil for non-forks and when the lookup fails.
    def fork_parent_full_name(repo)
      return nil unless repo.fork

      cache_key = "parent_#{repo.full_name}"
      return @cache[cache_key][:data] if cache_valid?(cache_key)

      parent_name = client.repo(repo.full_name).parent&.full_name
      @cache[cache_key] = { data: parent_name, timestamp: Time.now }
      parent_name
    rescue Octokit::Error
      nil
    end

    def cache_projects(cache_key, projects)
      @cache[cache_key] = {
        data: projects,
        timestamp: Time.now
      }
    end
  end
end
