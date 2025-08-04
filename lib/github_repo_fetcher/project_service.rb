# frozen_string_literal: true

require_relative 'github_client'

module GithubRepoFetcher
  # ProjectService handles business logic for fetching and processing user projects
  class ProjectService
    def initialize(github_client = nil)
      @github_client = github_client || GithubRepoFetcher::GithubClient.new
    end

    def fetch_user_projects(username)
      sanitized_username = sanitize_username(username)
      validate_username(sanitized_username)

      projects = @github_client.fetch_user_projects(sanitized_username)

      {
        username: sanitized_username,
        projects_count: projects.length,
        projects: projects
      }
    end

    private

    def sanitize_username(username)
      return nil if username.nil? || username.empty?

      # Remove any non-alphanumeric characters except hyphens and underscores
      # Convert to lowercase
      # Limit length to 39 characters (GitHub username limit)
      sanitized = username.downcase.gsub(/[^a-z0-9_-]/, '')
      sanitized[0, 39] # Limit to 39 characters
    end

    def validate_username(username)
      return unless username.nil? || username.empty?

      raise ArgumentError, 'Username is required as a query parameter'
    end
  end
end
