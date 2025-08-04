#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'json'
require 'net/http'
require 'selenium-webdriver'
require 'uri'

# Default API base URL
DEFAULT_API_URL = ENV.fetch('VERCEL_URL', 'https://github-project-fetch.vercel.app')

def build_test_uri(base_url, endpoint, params = {})
  uri = URI("#{base_url}/api/#{endpoint}")
  uri.query = URI.encode_www_form(params) if params.any?

  # Add Vercel protection bypass header
  bypass_secret = ENV.fetch('VERCEL_AUTOMATION_BYPASS_SECRET', nil)
  uri.query = [uri.query, "x-vercel-protection-bypass=#{bypass_secret}"].compact.join('&') if bypass_secret

  uri
end

def parse_json_response(content)
  JSON.parse(content)
rescue JSON::ParserError
  nil
end

def extract_json_from_html(page_source)
  json_match = page_source.match(%r{<pre>(.*?)</pre>}m)
  return nil unless json_match

  json_match[1]
end

def handle_json_response?(json_content, source_type)
  data = parse_json_response(json_content)
  if data
    puts "   ✅ Status: 200 OK (#{source_type})"
    puts "   📊 Response: #{JSON.pretty_generate(data)}"
  else
    puts "   📄 Response: #{json_content[0..500]}..."
  end
  true
end

def print_authentication_error
  puts '   ❌ Status: 401 Unauthorized'
  puts '   📄 Response: Authentication required page'
end

def print_not_found_error(page_source)
  puts '   ❌ Status: 404 Not Found'
  puts "   📄 Response: #{page_source[0..200]}..."
end

def print_unknown_error(page_source)
  puts '   ⚠️  Status: Unknown'
  puts "   📄 Response: #{page_source[0..500]}..."
end

def handle_error_response?(page_source)
  if page_source.include?('Authentication Required')
    print_authentication_error
  elsif page_source.include?('404') || page_source.include?('Not Found')
    print_not_found_error(page_source)
  else
    print_unknown_error(page_source)
  end
  false
end

def process_page_response?(page_source)
  # Try to extract JSON from HTML response
  json_content = extract_json_from_html(page_source)
  return handle_json_response?(json_content, 'JSON in HTML') if json_content

  # Check for direct JSON response
  return handle_json_response?(page_source, 'JSON response') if page_source.strip.start_with?('{', '[')

  # Handle error responses
  handle_error_response?(page_source)
end

def fetch_page_content(driver, uri)
  driver.get(uri.to_s)
  sleep(2) # Wait for page to load
  driver.page_source
end

def test_api_endpoint(driver, base_url, endpoint, params = {})
  uri = build_test_uri(base_url, endpoint, params)
  puts "🔮 Testing: #{uri}"

  begin
    page_source = fetch_page_content(driver, uri)
    process_page_response?(page_source)
  rescue StandardError => e
    warn "   ❌ Error: #{e.message}"
    false
  end
end

def setup_chrome_driver
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')

  Selenium::WebDriver.for :chrome, options: options
end

def run_test_suite(driver, api_url)
  tests = [
    { name: 'root endpoint', endpoint: '', expected: true },
    { name: 'health endpoint', endpoint: 'health', expected: true },
    { name: 'projects endpoint with username', endpoint: 'projects?octocat', expected: true },
    { name: 'projects endpoint without username', endpoint: 'projects', expected: true }
  ]

  success_count = 0
  total_tests = tests.length

  tests.each_with_index do |test, index|
    puts "#{index + 1}. Testing #{test[:name]}..."
    success_count += 1 if test_api_endpoint(driver, api_url, test[:endpoint])
    puts
  end

  [success_count, total_tests]
end

def print_summary(success_count, total_tests)
  puts '🎯 Test Summary'
  puts '=============='
  puts "✅ Passed: #{success_count}/#{total_tests}"
  puts "❌ Failed: #{total_tests - success_count}/#{total_tests}"

  if success_count == total_tests
    puts "\n🎉 All tests passed! The API is working correctly."
  else
    warn "\n⚠️  Some tests failed. Check the output above for details."
  end
end

def print_header(api_url)
  puts '🧙🏻 Testing GitHub Project Fetcher API'
  puts '====================================='
  puts "📍 API URL: #{api_url}"
  puts
end

def main
  api_url = ARGV.first || DEFAULT_API_URL
  print_header(api_url)

  driver = setup_chrome_driver

  begin
    success_count, total_tests = run_test_suite(driver, api_url)
    print_summary(success_count, total_tests)
  ensure
    driver&.quit
  end
end

main if __FILE__ == $PROGRAM_NAME
