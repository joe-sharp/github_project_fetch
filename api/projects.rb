# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/project_service'
require_relative '../lib/github_repo_fetcher/api_response_service'

# Vercel projects endpoint
Handler = proc do |request, response|
  GithubRepoFetcher::ApiResponseService.cors_headers(response)

  # Handle CORS preflight
  next if GithubRepoFetcher::ApiResponseService.cors_preflight?(request, response)

  begin
    # Get username from query parameters
    query_params = request.query || {}
    username = query_params.keys.first

    project_service = GithubRepoFetcher::ProjectService.new
    result = project_service.fetch_user_projects(username)

    GithubRepoFetcher::ApiResponseService.success_response(response, result)
  rescue ArgumentError => e
    GithubRepoFetcher::ApiResponseService.bad_request_response(response, e.message)
  rescue StandardError => e
    GithubRepoFetcher::ApiResponseService.error_response(response, e.message)
  end
end
