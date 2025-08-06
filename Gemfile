# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.3'

# Core dependencies
gem 'dotenv', '~> 3.1'
gem 'json', '~> 2.6'
gem 'jwt', '~> 3.1'
gem 'octokit', '~> 10.0'

# Development and testing
group :development, :test do
  gem 'rspec'
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rspec'
  gem 'selenium-webdriver'
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
