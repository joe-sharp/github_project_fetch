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
      client_ip = get_client_ip(request)
      check_rate_limit(client_ip)
      validate_request_size(request)
      check_for_malicious_input(username)
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
      # Check URL length (common safe limit is 2048 characters)
      url = request['path'] || ''
      query_string = request['querystring'] || ''
      full_url = "#{url}?#{query_string}"

      raise ArgumentError, 'Request URL exceeds maximum length of 2048 characters' if full_url.length > 2048

      # Check query string size separately (conservative limit of 1024 characters)
      raise ArgumentError, 'Query string exceeds maximum length of 1024 characters' if query_string.length > 1024

      # Check number of query parameters to prevent parameter pollution
      query_params = request.query || {}
      return unless query_params.keys.length > 10

      raise ArgumentError, 'Too many query parameters (maximum 10 allowed)'
    end

    def check_for_malicious_input(username)
      # Ensure username parameter is provided (basic security check)
      raise ArgumentError, 'Username parameter is required (e.g., ?username=value)' if username.nil?

      # Security check: prevent excessively long inputs that could cause DoS
      raise ArgumentError, 'Username exceeds maximum length of 100 characters' if username.length > 100

      # Security check: detect potential injection attempts or malicious patterns
      if username.match?(/[<>'"\\;{}()\[\]|&$`]/)
        raise ArgumentError, 'Username contains potentially malicious characters'
      end

      # Security check: prevent null bytes and control characters
      return unless username.match?(/[\u0000-\u001f\u007f-\u009f]/)

      raise ArgumentError, 'Username contains invalid control characters'
    end
  end
end
