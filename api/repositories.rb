# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/github_client'

# Vercel repositories endpoint
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
    # Get username from query parameters
    username = request.query['username']

    if username.nil? || username.empty?
      response.status = 400
      response.body = {
        error: 'Username parameter is required',
        example: '/api/repositories?username=octocat'
      }.to_json
    else
      github_client = GithubRepoFetcher::GithubClient.new
      repositories = github_client.fetch_user_repositories(username)

      response.status = 200
      response.body = {
        username: username,
        repositories_count: repositories.length,
        repositories: repositories
      }.to_json
    end
  rescue StandardError => e
    response.status = 500
    response.body = { error: e.message }.to_json
  end
end
