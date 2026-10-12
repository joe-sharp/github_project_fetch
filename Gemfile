# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.3'

# Core dependencies
gem 'dotenv', '~> 3.2'
gem 'json', '~> 3.0'
gem 'jwt', '~> 3.3'
gem 'octokit', '~> 10.0'

# Development and testing
group :development, :test do
  gem 'rspec'
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rspec'
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'webmock'
end

group :development do
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'guard-shell'
  gem 'pry'
  gem 'pry-byebug'
end
