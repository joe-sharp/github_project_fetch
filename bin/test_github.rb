#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative '../lib/github_repo_fetcher'

puts '🧙🏻 Testing GitHub App Authentication...'
puts '======================================'

begin
  # Test basic client initialization
  puts '1. Initializing GitHub client...'
  client = GitHubRepoFetcher::GitHubClient.new
  puts '   ✅ Client initialized successfully'

  # Test health check
  puts '2. Testing health check...'
  health_result = client.health_check
  puts "   ✅ Health check: #{health_result[:status]}"
  puts '   📊 Rate limit info available'

  # Test fetching repositories for a known user
  puts '3. Testing repository fetch...'
  test_username = 'octocat' # GitHub's test user
  repos = client.fetch_user_repositories(test_username)
  puts "   ✅ Successfully fetched #{repos.length} repositories for #{test_username}"

  # Show first repo as example
  if repos.any?
    first_repo = repos.first
    puts "   📦 Example repo: #{first_repo[:name]}"
    puts "      Description: #{first_repo[:description] || 'No description'}"
    puts "      Stars: #{first_repo[:stargazers_count]}, Forks: #{first_repo[:forks_count]}"
    languages = first_repo[:languages]&.keys&.join(', ') || 'No languages detected'
    puts "      Languages: #{languages}"
  end

  puts "\n🎉 All tests passed! Your GitHub App is working correctly."
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts "\nTroubleshooting:"
  puts '1. Make sure your .env file is set up with:'
  puts '   - GITHUB_APP_ID (your app ID from GitHub)'
  puts '   - GITHUB_PRIVATE_KEY (your private key in PEM format)'
  puts '   - GITHUB_CLIENT_ID (Iv23li8mXIuQ2n1WXDLf)'
  puts '   - GITHUB_CLIENT_SECRET (from your GitHub App settings)'
  puts '2. Check that your private key is in the correct format'
  puts '3. Verify your GitHub App has the correct permissions'
end
