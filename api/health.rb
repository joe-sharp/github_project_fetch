# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/health_service'
require_relative '../lib/github_repo_fetcher/api_response_service'

# Vercel health check endpoint - accessible at /api/health
Handler = proc do |request, response|
  ApiResponseService.cors_headers(response)

  # Handle CORS preflight
  next if ApiResponseService.cors_preflight?(request, response)

  begin
    health_service = GithubRepoFetcher::HealthService.new
    result = health_service.check_health

    status = result[:status] == 'healthy' ? 200 : 503
    ApiResponseService.success_response(response, result, status)
  rescue StandardError => e
    ApiResponseService.error_response(response, e.message, 503)
  end
end
