# frozen_string_literal: true

require "json"

module GithubRepoFetcher
  # ApiResponseService handles common API response formatting and CORS headers
  class ApiResponseService
    def self.cors_headers(response)
      response["Access-Control-Allow-Origin"] = "*"
      response["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
      response["Access-Control-Allow-Headers"] = "Content-Type"
      response["Content-Type"] = "application/json"
    end

    def self.cors_preflight?(request, response)
      method = request["method"] || "GET"

      if method == "OPTIONS"
        response.status = 200
        response.body = ""
        true
      else
        false
      end
    end

    # Add cache control headers for Vercel Edge Caching
    def self.add_cache_headers(response, max_age, stale_while_revalidate)
      response["Cache-Control"] = "s-maxage=#{max_age}, stale-while-revalidate=#{stale_while_revalidate}"
    end

    # Escape non-ASCII characters so the body stays valid even if the runtime
    # re-tags it as ASCII-8BIT (the Lambda marshaller fails on high bytes otherwise)
    def self.json_body(data)
      JSON.generate(data, ascii_only: true)
    end

    def self.success_response(response, data, status = 200)
      response.status = status
      response.body = json_body(data)
    end

    def self.cached_success_response(response, data, max_age = 600, stale_while_revalidate = 1200, status = 200)
      add_cache_headers(response, max_age, stale_while_revalidate)
      success_response(response, data, status)
    end

    def self.cached_html_response(response, html, max_age = 3600, stale_while_revalidate = 7200)
      response["Content-Type"] = "text/html; charset=utf-8"
      add_cache_headers(response, max_age, stale_while_revalidate)
      response.status = 200
      response.body = html
    end

    def self.error_response(response, error_message, status = 500)
      response.status = status
      response.body = json_body({ error: error_message })
    end

    def self.not_found_response(response, message = "Endpoint not found")
      error_response(response, message, 404)
    end

    def self.bad_request_response(response, message)
      error_response(response, message, 400)
    end
  end
end
