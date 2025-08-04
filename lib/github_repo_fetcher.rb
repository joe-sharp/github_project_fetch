# frozen_string_literal: true

require 'octokit'
require 'json'
require 'jwt'
require 'dotenv'

# Load environment variables
Dotenv.load

# Load other application files
require_relative 'github_repo_fetcher/github_client'
require_relative 'github_repo_fetcher/project_service'
require_relative 'github_repo_fetcher/health_service'
require_relative 'github_repo_fetcher/api_response_service'
