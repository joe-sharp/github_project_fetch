#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative '../lib/github_repo_fetcher'

puts '🔍 GitHub App Authentication Debug'
puts '=================================='

# Check environment variables
puts "\n1. Environment Variables Check:"
env_vars = %w[GITHUB_APP_ID GITHUB_PRIVATE_KEY GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET]
env_vars.each do |var|
  value = ENV.fetch(var, nil)
  if value.nil? || value.empty?
    puts "   ❌ #{var}: NOT SET"
  elsif var == 'GITHUB_PRIVATE_KEY'
    if value.include?('-----BEGIN RSA PRIVATE KEY-----')
      puts "   ✅ #{var}: SET (appears to be valid PEM format)"
      puts "      Length: #{value.length} characters"
      puts "      Contains BEGIN/END markers: #{value.include?('-----END RSA PRIVATE KEY-----')}"
    else
      puts "   ⚠️  #{var}: SET but doesn't look like PEM format"
      puts "      Value: #{value[0..50]}..."
    end
  else
    puts "   ✅ #{var}: SET"
  end
end

# Test GitHub Client initialization and JWT token generation
puts "\n2. GitHub Client Initialization Test:"
begin
  client = GitHubRepoFetcher::GitHubClient.new
  puts '   ✅ GitHubClient initialized successfully'

  # Test health check to verify API connection
  health = client.health_check
  puts "   ✅ Health check successful: #{health[:status]}"
  puts "      Rate limit: #{health[:rate_limit][:remaining]}/#{health[:rate_limit][:limit]}"
  puts "      Reset time: #{health[:rate_limit][:reset_time]}"
rescue StandardError => e
  puts "   ❌ Error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n      ")}"
end

# Test repository access (if client was initialized successfully)
puts "\n3. Repository Access Test:"
begin
  if defined?(client) && client
    puts '   Testing repository access...'
    # Try to fetch a public repository to test access
    test_username = 'octocat' # GitHub's test user
    repos = client.fetch_user_repositories(test_username)
    puts '   ✅ Repository access successful'
    puts "      Found #{repos.length} repositories for #{test_username}"
    puts "      Sample repo: #{repos.first[:name]}" if repos.any?
  else
    puts '   ❌ Cannot test repository access - client initialization failed'
  end
rescue StandardError => e
  puts "   ❌ Repository access failed: #{e.message}"
  if e.message.include?('401')
    puts '   💡 This suggests authentication issues'
  elsif e.message.include?('403')
    puts "   💡 This suggests the App doesn't have repository access permissions"
  elsif e.message.include?('404')
    puts '   💡 This suggests the test user was not found (unlikely)'
  end
end

puts "\n🔧 Troubleshooting Tips:"
puts '1. Make sure your private key includes the full PEM format with BEGIN/END markers'
puts "2. Verify your App ID matches what's shown in your GitHub App settings"
puts "3. Check that your GitHub App has 'Read repository data' permissions"
puts "4. Ensure your private key hasn't expired or been regenerated"
