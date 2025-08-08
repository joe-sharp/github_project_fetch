# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/github_repo_fetcher/security_service'

RSpec.describe GithubRepoFetcher::SecurityService do
  let(:service) { described_class.new }
  let(:mock_request) do
    {
      'path' => '/api/projects',
      'querystring' => 'username=testuser',
      'headers' => {},
      'query' => { 'username' => 'testuser' }
    }
  end

  describe '.validate_request' do
    it 'validates a legitimate request successfully' do
      expect { described_class.validate_request(mock_request, 'testuser') }.not_to raise_error
    end

    it 'raises error when username is nil' do
      expect { described_class.validate_request(mock_request, nil) }
        .to raise_error(ArgumentError, 'Username parameter is required (e.g., ?username=value)')
    end

    it 'raises error when username is empty' do
      expect { described_class.validate_request(mock_request, '') }
        .to raise_error(ArgumentError, 'Username parameter is required (e.g., ?username=value)')
    end
  end

  describe '#get_client_ip' do
    it 'extracts IP from x-forwarded-for header' do
      request = mock_request.merge('headers' => { 'x-forwarded-for' => '192.168.1.1, 10.0.0.1' })
      expect(service.send(:get_client_ip, request)).to eq('192.168.1.1')
    end

    it 'extracts IP from x-real-ip header' do
      request = mock_request.merge('headers' => { 'x-real-ip' => '192.168.1.2' })
      expect(service.send(:get_client_ip, request)).to eq('192.168.1.2')
    end

    it 'extracts IP from cf-connecting-ip header' do
      request = mock_request.merge('headers' => { 'cf-connecting-ip' => '192.168.1.3' })
      expect(service.send(:get_client_ip, request)).to eq('192.168.1.3')
    end

    it 'uses sourceIP when no headers present' do
      request = mock_request.merge('sourceIP' => '192.168.1.4')
      expect(service.send(:get_client_ip, request)).to eq('192.168.1.4')
    end

    it 'returns unknown when no IP information available' do
      request = mock_request.merge('headers' => {}, 'sourceIP' => nil)
      expect(service.send(:get_client_ip, request)).to eq('unknown')
    end
  end

  describe '#check_rate_limit' do
    let(:client_ip) { '192.168.1.1' }
    let(:window_size) { 300 }
    let(:requests) { {} }
    let(:max_requests) { 60 }

    it 'allows requests within rate limit' do
      expect { service.send(:check_rate_limit, client_ip, window_size, requests, max_requests) }
        .not_to raise_error
    end

    it 'raises error when rate limit exceeded' do
      # Fill up the rate limit
      requests[client_ip] = Array.new(max_requests) { Time.now.to_i }

      expect { service.send(:check_rate_limit, client_ip, window_size, requests, max_requests) }
        .to raise_error(ArgumentError, /Rate limit exceeded/)
    end

    it 'cleans up old entries outside the window' do
      old_time = Time.now.to_i - window_size - 10
      requests[client_ip] = [old_time, Time.now.to_i]

      service.send(:check_rate_limit, client_ip, window_size, requests, max_requests)

      expect(requests[client_ip].length).to eq(2) # old entry removed, new one added
    end
  end

  describe '#validate_request_size' do
    it 'allows requests within size limits' do
      expect { service.send(:validate_request_size, mock_request) }.not_to raise_error
    end

    it 'raises error when URL exceeds 1024 characters' do
      long_path = 'a' * 1025
      long_query = 'b' * 100
      request = mock_request.merge(
        'path' => "/#{long_path}",
        'querystring' => long_query
      )

      expect { service.send(:validate_request_size, request) }
        .to raise_error(ArgumentError, 'Request URL exceeds maximum length of 1024 characters')
    end

    it 'raises error when query string exceeds 512 characters' do
      long_query = 'a' * 513
      request = mock_request.merge('querystring' => long_query)

      expect { service.send(:validate_request_size, request) }
        .to raise_error(ArgumentError, 'Query string exceeds maximum length of 512 characters')
    end

    it 'raises error when too many query parameters' do
      many_params = (1..11).map { |i| "param#{i}=value#{i}" }.join('&')
      request = mock_request.merge(
        'querystring' => many_params,
        'query' => (1..11).to_h { |i| ["param#{i}", "value#{i}"] }
      )

      expect { service.send(:validate_request_size, request) }
        .to raise_error(ArgumentError, 'Too many query parameters (maximum 10 allowed)')
    end
  end

  describe '#check_for_malicious_input' do
    it 'allows valid usernames' do
      expect { service.send(:check_for_malicious_input, 'valid-user_123') }.not_to raise_error
    end

    it 'raises error when username exceeds 39 characters' do
      long_username = 'a' * 40
      expect { service.send(:check_for_malicious_input, long_username) }
        .to raise_error(ArgumentError, 'Username exceeds maximum length of 39 characters (GitHub username limit)')
    end

    it 'raises error for malicious characters' do
      malicious_inputs = ['<script>', 'user"name', 'user;name', '{username}', '[username]', 'user|name', 'user&name',
                          'user$name', 'user`name']

      malicious_inputs.each do |input|
        expect { service.send(:check_for_malicious_input, input) }
          .to raise_error(ArgumentError, 'Username contains potentially malicious characters')
      end
    end

    it 'raises error for control characters' do
      # Create strings with control characters using bytes
      control_chars = [
        "user#{0.chr}name",  # null byte
        "user#{31.chr}name", # unit separator
        "user#{127.chr}name", # delete
        "user#{159.chr}name"  # application program command
      ]

      control_chars.each do |input|
        expect { service.send(:check_for_malicious_input, input) }
          .to raise_error(ArgumentError, 'Username contains invalid control characters')
      end
    end

    it 'allows normal alphanumeric characters with hyphens and underscores' do
      valid_inputs = %w[user123 user-name user_name User123-Name_Test]

      valid_inputs.each do |input|
        expect { service.send(:check_for_malicious_input, input) }.not_to raise_error
      end
    end
  end
end
