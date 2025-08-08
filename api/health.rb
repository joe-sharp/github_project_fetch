# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/health_service'
require_relative '../lib/github_repo_fetcher/api_response_service'

# Vercel health check endpoint - accessible at /api/health
Handler = proc do |request, response|
  GithubRepoFetcher::ApiResponseService.cors_headers(response)

  # Handle CORS preflight
  next if GithubRepoFetcher::ApiResponseService.cors_preflight?(request, response)

  begin
    health_service = GithubRepoFetcher::HealthService.new
    result = health_service.check_health

    status = result[:status] == 'healthy' ? 200 : 503

    # Cache health status for 10 seconds with 1 minutes stale-while-revalidate
    # Health checks should be fresh but can tolerate some staleness
    GithubRepoFetcher::ApiResponseService.cached_success_response(
      response,
      result,
      10, # 10 seconds cache
      60, # 1 minute stale-while-revalidate
      status
    )
  rescue StandardError => e
    GithubRepoFetcher::ApiResponseService.error_response(response, e.message, 503)
  end
end
