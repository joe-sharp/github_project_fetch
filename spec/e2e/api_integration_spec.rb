# frozen_string_literal: true

#
# E2E Integration Tests
# ====================
# These tests are excluded from the default test suite due to their slow execution
# and external dependencies (Selenium WebDriver, live API calls).
#
# To run these tests specifically:
#   bin/test_api.rb
#   bin/test_api.rb <preview deployment URL>
#
# To run all tests including e2e:
#   RUN_E2E=true bundle exec rspec
#   VERCEL_URL=<preview deployment URL> RUN_E2E=true bundle exec rspec

require 'spec_helper'
require 'selenium-webdriver'
require 'json'
require 'uri'

# Handles URI building and parameter management
class UriBuilder
  def initialize(base_url)
    @base_url = base_url
    @bypass_secret = ENV.fetch('VERCEL_AUTOMATION_BYPASS_SECRET', nil)
    @bypass_secret = nil if base_url.match?(%r{^https://github-project-fetch.vercel.app})
  end

  def build(endpoint, username = nil)
    uri = URI(File.join(@base_url, 'api', endpoint))
    uri.query = username if username

    # Add Vercel protection bypass header
    uri.query = [uri.query, "x-vercel-protection-bypass=#{@bypass_secret}"].compact.join('&') if @bypass_secret

    uri
  end
end

# Handles JSON parsing and response processing
class ResponseProcessor
  def self.parse_json(content)
    JSON.parse(content)
  rescue JSON::ParserError
    nil
  end

  def self.extract_json_from_html(page_source)
    json_match = page_source.match(%r{<pre>(.*?)</pre>}m)
    return nil unless json_match

    json_match[1]
  end

  def self.process_response?(page_source)
    # Try to extract JSON from HTML response
    json_content = extract_json_from_html(page_source)
    return ResponseFormatter.json_response?(json_content, 'JSON in HTML') if json_content

    # Handle error responses
    ResponseFormatter.error_response?(page_source)
  end
end

# Handles response formatting and output
class ResponseFormatter
  def self.json_response?(json_content, source_type)
    data = ResponseProcessor.parse_json(json_content)
    if data
      puts "   ✅ Status: 200 OK (#{source_type})\n   " \
           "📊 Response: #{JSON.pretty_generate(data)}"
    else
      puts "   📄 Response: #{json_content[0..500]}..."
    end
    true
  end

  def self.error_response?(page_source)
    if page_source.include?('Authentication Required')
      warn "   ❌ Status: 401 Unauthorized\n" \
           '📄 Response: Authentication required page'
    elsif page_source.include?('404') || page_source.include?('Not Found')
      warn "   ❌ Status: 404 Not Found\n" \
           "📄 Response: #{page_source[0..200]}..."
    else
      warn "   ⚠️  Status: Unknown\n" \
           "📄 Response: #{page_source[0..500]}..."
    end
    false
  end
end

# Manages Selenium WebDriver lifecycle
class WebDriverManager
  def initialize
    @driver = nil
  end

  def setup
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920,1080')

    @driver = Selenium::WebDriver.for :chrome, options: options
  end

  def fetch_page(uri)
    @driver.get(uri.to_s)
    wait = Selenium::WebDriver::Wait.new(timeout: 2)
    wait.until { @driver.find_element(:tag_name, 'pre') }
    @driver.page_source
  end

  def cleanup
    @driver&.quit
  end
end

# API Integration test suite for end-to-end testing
class ApiIntegration
  def self.endpoint_responsive?(uri_builder, driver_manager, endpoint, username = nil)
    uri = uri_builder.build(endpoint, username)
    puts "🔮 Testing: #{uri}"

    page_source = driver_manager.fetch_page(uri)
    ResponseProcessor.process_response?(page_source)
  end
end

RSpec.describe ApiIntegration, :e2e do
  let(:api_url) { ENV.fetch('VERCEL_URL', 'https://github-project-fetch.vercel.app') }
  let(:uri_builder) { UriBuilder.new(api_url) }
  let(:driver_manager) { WebDriverManager.new }

  before do
    puts "🧙🏻 Testing GitHub Project Fetcher API\n" \
         "=====================================\n" \
         "📍 API URL: #{api_url}\n\n"
    driver_manager.setup
  end

  after do
    driver_manager.cleanup
  end

  describe 'API endpoints' do
    it 'responds to root endpoint', :aggregate_failures do
      result = described_class.endpoint_responsive?(uri_builder, driver_manager, '')
      expect(result).to be true
    end

    it 'responds to health endpoint', :aggregate_failures do
      result = described_class.endpoint_responsive?(uri_builder, driver_manager, 'health')
      expect(result).to be true
    end

    it 'responds to projects endpoint with username', :aggregate_failures do
      result = described_class.endpoint_responsive?(uri_builder, driver_manager, 'projects', 'username=octocat')
      expect(result).to be true
    end

    it 'responds to projects endpoint without username', :aggregate_failures do
      result = described_class.endpoint_responsive?(uri_builder, driver_manager, 'projects')
      expect(result).to be true
    end
  end
end
