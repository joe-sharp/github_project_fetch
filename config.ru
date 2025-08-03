require 'bundler/setup'
require 'dotenv'

# Load environment variables
Dotenv.load('.env')

# Load the application
require_relative 'lib/github_repo_fetcher'

# Run the Sinatra app
run GitHubRepoFetcher::App
