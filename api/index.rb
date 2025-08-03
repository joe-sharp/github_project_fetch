# frozen_string_literal: true

require 'json'

# Vercel serverless function handler
Handler = proc do |request, response|
  method = request['method'] || 'GET'
  path = request['path'] || '/'

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
    case path
    when '/', '/api'
      response.status = 200
      response.body = {
        name: 'GitHub Repository Fetcher',
        version: '1.0.0',
        description: 'API to fetch public repositories from GitHub users',
        endpoints: {
          health: '/api/health',
          repositories: '/api/repositories?username=:username'
        },
        examples: {
          health: '/api/health',
          repositories: '/api/repositories?username=octocat'
        }
      }.to_json
    else
      response.status = 404
      response.body = { error: 'Endpoint not found' }.to_json
    end
  rescue StandardError => e
    response.status = 500
    response.body = { error: e.message }.to_json
  end
end
