# frozen_string_literal: true

source "https://rubygems.org"

ruby "~> 3.3"

# Core dependencies
gem "dotenv", "~> 3.2"
gem "json", "~> 3.1"
gem "jwt", "~> 3.3"
gem "octokit", "~> 10.0"

# Development and testing
group :development, :test do
  gem "rspec"
  # Pinned to the unreleased `AllowedReceivers` option for Style/MethodCallWithArgsParentheses
  # (rubocop/rubocop#16193). Drop this once a RuboCop release includes it.
  gem "rubocop", github: "joe-sharp/rubocop", branch: "method-call-with-args-parentheses-allowed-receivers"
  gem "rubocop-performance"
  gem "rubocop-rspec"
  gem "selenium-webdriver"
  gem "sharp_style_rubocop", "~> 0.1"
  gem "simplecov"
  gem "webmock"
end

group :development do
  gem "guard"
  gem "guard-rspec"
  gem "guard-rubocop"
  gem "guard-shell"
  gem "pry"
  gem "pry-byebug"
end
