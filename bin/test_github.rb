#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative '../lib/github_repo_fetcher'

puts '🧙🏻 Testing GitHub App Authentication...'
puts '======================================'

begin
  # Test basic client initialization
  puts '1. Initializing GitHub client...'
  client = GithubRepoFetcher::GithubClient.new
  puts '   ✅ Client initialized successfully'

  # Test health check
  puts '2. Testing health check...'
  health_service = GithubRepoFetcher::HealthService.new(client)
  health_result = health_service.check_health
  puts "   ✅ Health check: #{health_result[:status]}"
  puts "   📊 Rate limit: #{health_result[:rate_limit][:remaining]}/#{health_result[:rate_limit][:limit]} remaining"

  # Test fetching projects for a known user
  puts '3. Testing project fetch...'
  test_username = 'octocat' # GitHub's test user
  projects = client.fetch_user_projects(test_username)
  puts "   ✅ Successfully fetched #{projects.length} projects for #{test_username}"

  # Show first project as example
  if projects.any?
    # Try to find linguist project first, otherwise use the first project
    project = projects.find { |project| project[:name] == 'linguist' } || projects.first
    puts "   📦 Example repo: #{project[:name]}"
    puts "      Description: #{project[:description] || 'No description'}"
    puts "      Stars: #{project[:stargazers_count]}, Forks: #{project[:forks_count]}"
    puts "      Languages: #{project[:languages] || 'No languages detected'}"
  end

  puts "\n🎉 All tests passed! Your GitHub App is working correctly."
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts "\nTroubleshooting:"
  puts '1. Make sure your .env file is set up with:'
  puts '   - GITHUB_APP_ID (your app ID from GitHub)'
  puts '   - GITHUB_PRIVATE_KEY (your private key in PEM format)'
  puts '   - GITHUB_CLIENT_ID (your client ID from GitHub)'
  puts '   - GITHUB_CLIENT_SECRET (from your GitHub App settings)'
  puts '2. Check that your private key is in the correct format'
  puts '3. Verify your GitHub App has the correct permissions'
end
