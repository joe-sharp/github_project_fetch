# frozen_string_literal: true

module GithubRepoFetcher
  # GitHub's languages API omits data/prose languages (YAML, JSON, Markdown), so repos
  # made of them report {}. This counts file bytes by extension from a git tree instead.
  module LanguageFallback
    EXTENSIONS = { 'yml' => 'YAML', 'yaml' => 'YAML', 'json' => 'JSON',
                   'md' => 'Markdown', 'markdown' => 'Markdown' }.freeze

    def self.fetch(client, full_name, branch)
      return {} unless branch

      from_tree(client.tree(full_name, branch, recursive: true).tree)
    end

    def self.from_tree(entries)
      entries.each_with_object(Hash.new(0)) do |entry, totals|
        next unless entry.type == 'blob'

        language = EXTENSIONS[File.extname(entry.path).delete_prefix('.').downcase]
        totals[language] += entry.size.to_i if language
      end.to_h
    end
  end
end
