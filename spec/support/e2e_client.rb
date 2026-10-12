# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Talks to a deployed instance (Vercel preview or production) for the E2E specs.
#
# The Vercel Deployment Protection bypass secret is sent as a header for API calls, and as a
# one-off query parameter that sets a cookie for browser sessions.
class E2eClient
  PRODUCTION_HOST = 'github-project-fetch.vercel.app'

  def self.base_url
    url = ENV.fetch('VERCEL_URL', "https://#{PRODUCTION_HOST}")
    url = "https://#{url}" unless url.start_with?('http')
    url.chomp('/')
  end

  def self.bypass_secret
    return nil if URI(base_url).host == PRODUCTION_HOST

    ENV.fetch('VERCEL_AUTOMATION_BYPASS_SECRET', nil)
  end

  # Returns Net::HTTPResponse. Pass accept: to control content negotiation.
  def self.request(path, method: :get, accept: 'application/json')
    uri = URI("#{base_url}#{path}")
    headers = { 'Accept' => accept }
    headers['x-vercel-protection-bypass'] = bypass_secret if bypass_secret

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 30) do |http|
      http.send_request(method.to_s.upcase, uri.request_uri, nil, headers)
    end
  end

  def self.json(response)
    JSON.parse(response.body)
  end

  # Browser URL that also asks Vercel to set the bypass cookie for follow-up fetches
  def self.browser_url(path)
    return "#{base_url}#{path}" unless bypass_secret

    separator = path.include?('?') ? '&' : '?'
    "#{base_url}#{path}#{separator}x-vercel-protection-bypass=#{bypass_secret}&x-vercel-set-bypass-cookie=true"
  end
end
