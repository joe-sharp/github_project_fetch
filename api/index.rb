# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/api_response_service'

# Vercel serverless function handler
Handler = proc do |request, response|
  GithubRepoFetcher::ApiResponseService.cors_headers(response)

  # Handle CORS preflight
  next if GithubRepoFetcher::ApiResponseService.cors_preflight?(request, response)

  begin
    path = request['path'] || '/'

    case path
    when '/', '/api'
      data = {
        name: 'GitHub Project Fetcher',
        version: '1.0.0',
        description: 'API to fetch public repositories and their language data for a given GitHub user. ' \
                     '(Unrelated to GitHub Projects)',
        endpoints: {
          health: '/api/health',
          projects: '/api/projects?username'
        },
        examples: {
          health: '/api/health',
          projects: '/api/projects?octocat'
        }
      }
      GithubRepoFetcher::ApiResponseService.success_response(response, data)
    else
      GithubRepoFetcher::ApiResponseService.not_found_response(response)
    end
  rescue StandardError => e
    GithubRepoFetcher::ApiResponseService.error_response(response, e.message)
  end
end
