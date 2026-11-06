# frozen_string_literal: true

require "json"
require_relative "../lib/github_repo_fetcher/project_service"
require_relative "../lib/github_repo_fetcher/api_response_service"
require_relative "../lib/github_repo_fetcher/security_service"

# Vercel projects endpoint
Handler = proc do |request, response|
  GithubRepoFetcher::ApiResponseService.cors_headers(response)

  # Handle CORS preflight
  next if GithubRepoFetcher::ApiResponseService.cors_preflight?(request, response)

  begin
    # Get username from query parameters
    query_params = request.query || {}
    username = query_params["username"]
    # Fork fields cost an extra GitHub lookup per fork, so they are opt-in
    include_fork_metadata = query_params["include_fork_metadata"] == "true"

    # Validate request and enforce security policies
    GithubRepoFetcher::SecurityService.validate_request(request, username)

    project_service = GithubRepoFetcher::ProjectService.new
    result = project_service.fetch_user_projects(username, include_fork_metadata: include_fork_metadata)

    # Cache GitHub data for 10 minutes with 20 minutes stale-while-revalidate
    # This balances freshness with performance for public repository data
    GithubRepoFetcher::ApiResponseService.cached_success_response(
      response,
      result,
      600, # 10 minutes cache
      1200 # 20 minutes stale-while-revalidate
    )
  rescue ArgumentError => e
    GithubRepoFetcher::ApiResponseService.bad_request_response(response, e.message)
  rescue => e
    GithubRepoFetcher::ApiResponseService.error_response(response, e.message)
  end
end
