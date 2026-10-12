# frozen_string_literal: true

# Helpers for exercising the Vercel handlers in api/*.rb without a server.
module HandlerHelper
  # Hash-like request that also responds to #query, like Vercel's request object
  class FakeRequest
    attr_reader :query

    def initialize(data, query)
      @data = data
      @query = query
    end

    def [](key)
      @data[key]
    end
  end

  # Minimal stand-in for Vercel's response object
  class FakeResponse
    attr_accessor :status, :body

    def headers
      @headers ||= {}
    end

    def []=(key, value)
      headers[key] = value
    end

    def [](key)
      headers[key]
    end

    def json
      JSON.parse(body)
    end
  end

  # Every handler file assigns the top-level Handler constant, so clear it before each load.
  def run_handler(name, method: 'GET', path: '/api', query: {}, headers: {})
    Object.send(:remove_const, :Handler) if Object.const_defined?(:Handler) # rubocop:disable RSpec/RemoveConst
    load File.expand_path("../../api/#{name}.rb", __dir__)

    request = FakeRequest.new(
      {
        'method' => method,
        'path' => path,
        'headers' => headers,
        'accept' => headers['accept'],
        'querystring' => URI.encode_www_form(query),
        'sourceIP' => '203.0.113.7'
      },
      query
    )
    FakeResponse.new.tap { |response| Handler.call(request, response) }
  end
end

RSpec.configure do |config|
  config.include HandlerHelper, type: :handler
end
