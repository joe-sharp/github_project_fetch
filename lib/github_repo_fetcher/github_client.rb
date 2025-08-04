# frozen_string_literal: true

require 'octokit'
require 'jwt'

module GithubRepoFetcher
  # GithubClient handles authentication and interaction with the GitHub API
  # It provides methods to fetch repository data and check API health status
  # Uses JWT authentication for GitHub App integration and implements caching
  class GithubClient
    attr_reader :client

    def initialize
      @app_id = ENV.fetch('GITHUB_APP_ID', nil)
      @private_key = ENV.fetch('GITHUB_PRIVATE_KEY', nil)
      @client_id = ENV.fetch('GITHUB_CLIENT_ID', nil)
      @client_secret = ENV.fetch('GITHUB_CLIENT_SECRET', nil)
      @cache = {}
      @cache_ttl = 300 # 5 minutes cache

      validate_configuration
      setup_client
    end

    def fetch_user_repositories(username) # rubocop:disable Metrics/MethodLength
      cache_key = "repos_#{username}"
      return @cache[cache_key][:data] if cache_valid?(cache_key)

      repositories = fetch_and_transform_repositories(username)
      cache_repositories(cache_key, repositories)
      repositories
    rescue Octokit::NotFound
      raise "User '#{username}' not found"
    rescue Octokit::TooManyRequests
      raise 'GitHub API rate limit exceeded. Please try again later.'
    rescue Octokit::Error => e
      raise "GitHub API error: #{e.message}"
    end

    def health_check
      rate_limit_info = client.rate_limit
      remaining = rate_limit_info.remaining
      limit = rate_limit_info.limit
      reset_time = Time.at(rate_limit_info.resets_at)

      {
        status: 'healthy',
        message: 'GitHub API connection successful',
        rate_limit: {
          remaining: remaining,
          limit: limit,
          reset_time: reset_time.iso8601,
          used_percentage: ((limit - remaining).to_f / limit * 100).round(2)
        }
      }
    rescue Octokit::Error => e
      { status: 'unhealthy', message: "GitHub API error: #{e.message}" }
    end

    private

    def validate_configuration
      required_vars = %w[GITHUB_APP_ID GITHUB_PRIVATE_KEY GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET]
      missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }

      return if missing_vars.empty?

      raise "Missing required environment variables: #{missing_vars.join(', ')}"
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
      return log_no_installations unless installations.any?

      setup_client_with_installation(installations.first)
    rescue Octokit::Unauthorized => e
      log_installation_error("Authentication failed during installation setup: #{e.message}")
    rescue Octokit::Error => e
      log_installation_error("Could not set up installation client: #{e.message}")
    rescue StandardError => e
      log_installation_error("Unexpected error during installation setup: #{e.message}")
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

    def log_no_installations
      warn '⚠️  No installations found. Install the app to access repositories.'
    end

    def log_installation_error(message)
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
      JWT.encode(payload, private_key, 'RS256')
    rescue JWT::EncodeError => e
      raise "Failed to generate JWT token: #{e.message}"
    rescue OpenSSL::PKey::RSAError => e
      raise "Failed to parse private key: #{e.message}"
    end

    def fetch_repository_languages(full_name)
      cache_key = "languages_#{full_name}"
      return @cache[cache_key][:data] if cache_valid?(cache_key)

      languages = client.languages(full_name)

      # Convert Sawyer::Resource to hash for JSON serialization
      languages_hash = languages.to_h

      # Cache the results
      @cache[cache_key] = {
        data: languages_hash,
        timestamp: Time.now
      }

      languages_hash
    rescue Octokit::Error
      # Return empty hash if languages can't be fetched
      {}
    end

    def cache_valid?(key)
      return false unless @cache[key]

      (Time.now - @cache[key][:timestamp]) < @cache_ttl
    end

    def fetch_and_transform_repositories(username)
      client.repos(username, per_page: 100).map do |repo|
        transform_repository_data(repo)
      end
    end

    def transform_repository_data(repo)
      {
        name: repo.name,
        description: repo.description,
        languages: fetch_repository_languages(repo.full_name),
        forks_count: repo.forks_count,
        stargazers_count: repo.stargazers_count,
        html_url: repo.html_url,
        created_at: repo.created_at,
        updated_at: repo.updated_at
      }
    end

    def cache_repositories(cache_key, repositories)
      @cache[cache_key] = {
        data: repositories,
        timestamp: Time.now
      }
    end
  end
end
