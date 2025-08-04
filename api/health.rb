# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/github_client'

# Vercel health check endpoint - accessible at /api/health
Handler = proc do |request, response|
  method = request['method'] || 'GET'

  # Set CORS headers
  response['Access-Control-Allow-Origin'] = '*'
  response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response['Access-Control-Allow-Headers'] = 'Content-Type'
  response['Content-Type'] = 'application/json'

  # Handle CORS preflight
  if method == 'OPTIONS'
    response.status = 200
    response.body = ''
    next
  end

  begin
    github_client = GithubRepoFetcher::GithubClient.new
    result = github_client.health_check

    response.status = result[:status] == 'healthy' ? 200 : 503
    response.body = result.to_json
  rescue StandardError => e
    response.status = 503
    response.body = {
      status: 'unhealthy',
      error: e.message,
      timestamp: Time.now.iso8601,
      service: 'GitHub Repository Fetcher',
      version: '1.0.0'
    }.to_json
  end
end
