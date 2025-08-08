# frozen_string_literal: true

module GithubRepoFetcher
  # SecurityService handles request validation, rate limiting, and security checks
  class SecurityService
    # Simple in-memory rate limiter (resets on function cold start)
    RATE_LIMITER = {
      requests: {},
      window_size: 300, # 5 minutes
      max_requests: 60  # 60 requests per 5 minutes per IP
    }.freeze

    def self.validate_request(request, username)
      new.validate_request(request, username)
    end

    def validate_request(request, username)
      # Check username first before other validations
      check_for_malicious_input(username)

      client_ip = get_client_ip(request)
      check_rate_limit(client_ip)
      validate_request_size(request)
    end

    private

    def get_client_ip(request)
      # Try to get real IP from headers (common in serverless environments)
      x_forwarded_for_ip(request) ||
        x_real_ip(request) ||
        cf_connecting_ip(request) || # Cloudflare
        request['sourceIP'] ||
        'unknown'
    end

    def x_forwarded_for_ip(request)
      request['headers']&.dig('x-forwarded-for')&.split(',')&.first&.strip # rubocop:disable Style/SafeNavigationChainLength
    end

    def x_real_ip(request)
      request['headers']&.dig('x-real-ip')
    end

    def cf_connecting_ip(request)
      request['headers']&.dig('cf-connecting-ip')
    end

    def check_rate_limit(client_ip,
                         window_size = RATE_LIMITER[:window_size],
                         requests = RATE_LIMITER[:requests],
                         max_requests = RATE_LIMITER[:max_requests])
      current_time = Time.now.to_i
      window_start = current_time - window_size

      # Clean old entries
      requests.reject! { |_, timestamps| timestamps.last < window_start }

      # Get current requests for this IP
      ip_requests = requests[client_ip] ||= []

      # Remove old requests outside the window
      ip_requests.reject! { |timestamp| timestamp < window_start }

      # Check if limit exceeded
      if ip_requests.length >= max_requests
        raise ArgumentError,
              "Rate limit exceeded. Maximum #{max_requests} requests per #{window_size / 60} minutes."
      end

      # Add current request
      ip_requests << current_time
    end

    def validate_request_size(request)
      # Check URL length (reasonable limit for GitHub API)
      url = request['path'] || ''
      query_string = request['querystring'] || ''
      full_url = "#{url}?#{query_string}"

      raise ArgumentError, 'Request URL exceeds maximum length of 1024 characters' if full_url.length > 1024

      # Check query string size separately (reasonable limit for username parameter)
      raise ArgumentError, 'Query string exceeds maximum length of 512 characters' if query_string.length > 512

      # Check number of query parameters to prevent parameter pollution
      query_params = request['query'] || {}
      return unless query_params.keys.length > 10

      raise ArgumentError, 'Too many query parameters (maximum 10 allowed)'
    end

    def check_for_malicious_input(username)
      validate_username_presence(username)
      validate_username_length(username)
      validate_username_characters(username)
      validate_username_control_chars(username)
    end

    def validate_username_presence(username)
      return unless username.nil? || username.empty?

      raise ArgumentError, 'Username parameter is required (e.g., ?username=value)'
    end

    def validate_username_length(username)
      return unless username.length > 39

      raise ArgumentError, 'Username exceeds maximum length of 39 characters (GitHub username limit)'
    end

    def validate_username_characters(username)
      unsafe_characters = /[<>'"\\;{}()\[\]|&$`]/
      return unless username.match?(unsafe_characters)

      raise ArgumentError, 'Username contains potentially malicious characters'
    end

    def validate_username_control_chars(username)
      return unless username.bytes.any? { |byte| byte.between?(0, 31) || byte.between?(127, 159) }

      raise ArgumentError, 'Username contains invalid control characters'
    end
  end
end
