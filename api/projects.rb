# frozen_string_literal: true

require 'json'
require_relative '../lib/github_repo_fetcher/github_client'

# Helper method for username sanitization
def sanitize_username(username)
  return nil if username.nil? || username.empty?

  # Remove any non-alphanumeric characters except hyphens and underscores
  # Convert to lowercase
  # Limit length to 39 characters (GitHub username limit)
  sanitized = username.downcase.gsub(/[^a-z0-9_-]/, '')
  sanitized[0, 39] # Limit to 39 characters
end

# Vercel projects endpoint
Handler = proc do |request, response| # rubocop:disable Metrics/BlockLength
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
    # In Vercel, request.query is a hash of parsed query parameters
    # We'll look for a username parameter or use the first parameter
    query_params = request.query || {}
    username = query_params.keys.first

    if username.nil? || username.empty?
      response.status = 400
      response.body = {
        error: 'Username is required as a query parameter',
        example: '/api/projects?octocat'
      }.to_json
    else
      # Sanitize username for security
      sanitized_username = sanitize_username(username)

      github_client = GithubRepoFetcher::GithubClient.new
      projects = github_client.fetch_user_projects(sanitized_username)

      response.status = 200
      response.body = {
        username: sanitized_username,
        projects_count: projects.length,
        projects: projects
      }.to_json
    end
  rescue StandardError => e
    response.status = 500
    response.body = { error: e.message }.to_json
  end
end
