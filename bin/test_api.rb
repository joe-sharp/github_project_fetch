#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

# Simple wrapper to run E2E API tests
# Run only the e2e tests
URL = ARGV.first
VERCEL_URL = URL ? "VERCEL_URL=#{URL}" : ''
system("#{VERCEL_URL} RUN_E2E=true bundle exec rspec --tag e2e")
