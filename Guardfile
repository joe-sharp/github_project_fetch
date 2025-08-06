# frozen_string_literal: true

# More info at https://github.com/guard/guard#readme

guard :rubocop, cli: '--format progress --out tmp/rubocop_status.txt ',
                all_on_start: true, all_after_pass: true do
  watch(/.+\.rb$/)
  watch(/bin/)
  watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
end

guard :rspec, cmd: 'bundle exec rspec --format progress --out tmp/rspec_status.txt --format progress 2> /dev/null',
              all_on_start: true, all_after_pass: true do
  require 'guard/rspec/dsl'
  dsl = Guard::RSpec::Dsl.new(self)

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper) { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)

  # Ruby files
  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)

  # Watch lib files and run corresponding specs
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/github_repo_fetcher/(?<filename>.+)\.rb$}) { |m| "spec/github_repo_fetcher/#{m[:filename]}_spec.rb" }

  # Watch API files and run all specs (since they're integration points)
  watch(%r{^api/(.+)\.rb$}) { 'spec' }
end

# Shell guard for running status summary after changes
guard :shell, all_on_start: true do
  watch(/^(lib|spec|api|bin).*$/) do
    `bin/status_summary`
  end
end
