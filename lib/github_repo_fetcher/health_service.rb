# frozen_string_literal: true

require_relative 'github_client'

module GithubRepoFetcher
  # HealthService handles business logic for health checks
  class HealthService
    def initialize(github_client = nil)
      @github_client = github_client || GithubRepoFetcher::GithubClient.new
    end

    def check_health
      rate_limit_info = @github_client.rate_limit
      healthy_response(rate_limit_info)
    rescue StandardError => e
      unhealthy_response(e)
    end

    private

    def healthy_response(rate_limit_info)
      base_response.merge(
        status: 'healthy',
        message: 'GitHub API connection successful',
        rate_limit: build_rate_limit_data(rate_limit_info)
      )
    end

    def unhealthy_response(error)
      base_response.merge(
        status: 'unhealthy',
        error: error.message
      )
    end

    def build_rate_limit_data(rate_limit_info)
      remaining = rate_limit_info.remaining
      limit = rate_limit_info.limit
      reset_time = Time.at(rate_limit_info.resets_at)

      {
        remaining: remaining,
        limit: limit,
        reset_time: reset_time.iso8601,
        used_percentage: calculate_used_percentage(remaining, limit)
      }
    end

    def calculate_used_percentage(remaining, limit)
      ((limit - remaining).to_f / limit * 100).round(2)
    end

    def base_response
      {
        timestamp: Time.now.utc.iso8601,
        service: 'GitHub Repository Fetcher',
        version: '1.0.0'
      }
    end
  end
end
