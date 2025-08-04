# frozen_string_literal: true

require_relative 'github_client'

module GithubRepoFetcher
  # HealthService handles business logic for health checks
  class HealthService
    def initialize(github_client = nil)
      @github_client = github_client || GithubRepoFetcher::GithubClient.new
    end

    def check_health
      @github_client.health_check
    rescue StandardError => e
      {
        status: 'unhealthy',
        error: e.message,
        timestamp: Time.now.utc.iso8601,
        service: 'GitHub Repository Fetcher',
        version: '1.0.0'
      }
    end
  end
end
