# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/project_service'
require_relative '../lib/github_repo_fetcher/api_response_service'

# Vercel projects endpoint
Handler = proc do |request, response|
  ApiResponseService.cors_headers(response)

  # Handle CORS preflight
  next if ApiResponseService.cors_preflight?(request, response)

  begin
    # Get username from query parameters
    query_params = request.query || {}
    username = query_params.keys.first

    project_service = GithubRepoFetcher::ProjectService.new
    result = project_service.fetch_user_projects(username)

    ApiResponseService.success_response(response, result)
  rescue ArgumentError => e
    ApiResponseService.bad_request_response(response, e.message)
  rescue StandardError => e
    ApiResponseService.error_response(response, e.message)
  end
end
