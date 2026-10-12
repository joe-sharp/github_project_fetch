# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/api_response_service'
require_relative '../lib/github_repo_fetcher/usage_service'

# Vercel serverless function handler
Handler = proc do |request, response|
  GithubRepoFetcher::ApiResponseService.cors_headers(response)

  # Handle CORS preflight
  next if GithubRepoFetcher::ApiResponseService.cors_preflight?(request, response)

  begin
    path = request['path'] || '/'

    case path
    when '/', '/api'
      # Same URL serves a styled guide to browsers and JSON to everything else
      response['Vary'] = 'Accept'

      # Cache usage docs for 1 hour with 2 hours stale-while-revalidate
      # Documentation rarely changes and can be cached longer
      if GithubRepoFetcher::UsageService.html_requested?(request)
        GithubRepoFetcher::ApiResponseService.cached_html_response(response, GithubRepoFetcher::UsageService.html)
      else
        GithubRepoFetcher::ApiResponseService.cached_success_response(
          response,
          GithubRepoFetcher::UsageService.json,
          3600,  # 1 hour cache
          7200   # 2 hours stale-while-revalidate
        )
      end
    else
      GithubRepoFetcher::ApiResponseService.not_found_response(response)
    end
  rescue StandardError => e
    GithubRepoFetcher::ApiResponseService.error_response(response, e.message)
  end
end
