# frozen_string_literal: true

module GithubRepoFetcher
  # ApiResponseService handles common API response formatting and CORS headers
  class ApiResponseService
    def self.cors_headers(response)
      response['Access-Control-Allow-Origin'] = '*'
      response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
      response['Access-Control-Allow-Headers'] = 'Content-Type'
      response['Content-Type'] = 'application/json'
    end

    def self.cors_preflight?(request, response)
      method = request['method'] || 'GET'

      if method == 'OPTIONS'
        response.status = 200
        response.body = ''
        true
      else
        false
      end
    end

    # Add cache control headers for Vercel Edge Caching
    def self.add_cache_headers(response, max_age, stale_while_revalidate)
      response['Cache-Control'] = "s-maxage=#{max_age}, stale-while-revalidate=#{stale_while_revalidate}"
    end

    def self.success_response(response, data, status = 200)
      response.status = status
      response.body = data.to_json
    end

    def self.cached_success_response(response, data, max_age = 600, stale_while_revalidate = 1200, status = 200)
      add_cache_headers(response, max_age, stale_while_revalidate)
      success_response(response, data, status)
    end

    def self.error_response(response, error_message, status = 500)
      response.status = status
      response.body = { error: error_message }.to_json
    end

    def self.not_found_response(response, message = 'Endpoint not found')
      error_response(response, message, 404)
    end

    def self.bad_request_response(response, message)
      error_response(response, message, 400)
    end
  end
end
