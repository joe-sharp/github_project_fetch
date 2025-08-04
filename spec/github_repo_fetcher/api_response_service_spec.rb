# frozen_string_literal: true

require 'spec_helper'

# Simple test class that implements the response interface
class MockResponse
  def []=(key, value)
    # Mock implementation
  end

  def status=(value)
    # Mock implementation
  end

  def body=(value)
    # Mock implementation
  end
end

# Simple test class that implements the request interface
class MockRequest
  def [](key)
    # Mock implementation
  end
end

RSpec.describe GithubRepoFetcher::ApiResponseService do
  describe '.cors_headers' do
    it 'sets the expected CORS headers', :aggregate_failures do
      response = instance_spy(MockResponse)
      allow(response).to receive(:[]=)

      described_class.cors_headers(response)

      expect(response).to have_received(:[]=).with('Access-Control-Allow-Origin', '*')
      expect(response).to have_received(:[]=).with('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      expect(response).to have_received(:[]=).with('Access-Control-Allow-Headers', 'Content-Type')
      expect(response).to have_received(:[]=).with('Content-Type', 'application/json')
    end
  end

  describe '.cors_preflight?' do
    it 'returns true and sets response for OPTIONS method', :aggregate_failures do
      request = instance_spy(MockRequest)
      response = instance_spy(MockResponse)
      allow(request).to receive(:[]).and_return('OPTIONS')
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      result = described_class.cors_preflight?(request, response)

      expect(result).to be true
      expect(response).to have_received(:status=).with(200)
      expect(response).to have_received(:body=).with('')
    end

    it 'returns false for non-OPTIONS methods' do
      request = instance_spy(MockRequest)
      response = instance_spy(MockResponse)
      allow(request).to receive(:[]).and_return('GET')

      result = described_class.cors_preflight?(request, response)

      expect(result).to be false
    end
  end

  describe '.success_response' do
    it 'sets status and body correctly', :aggregate_failures do
      response = instance_spy(MockResponse)
      data = { message: 'Success' }
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      described_class.success_response(response, data)

      expect(response).to have_received(:status=).with(200)
      expect(response).to have_received(:body=).with(data.to_json)
    end

    it 'accepts custom status code', :aggregate_failures do
      response = instance_spy(MockResponse)
      data = { message: 'Created' }
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      described_class.success_response(response, data, 201)

      expect(response).to have_received(:status=).with(201)
    end
  end

  describe '.error_response' do
    it 'sets error status and message', :aggregate_failures do
      response = instance_spy(MockResponse)
      error_message = 'Something went wrong'
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      described_class.error_response(response, error_message)

      expect(response).to have_received(:status=).with(500)
      expect(response).to have_received(:body=).with({ error: error_message }.to_json)
    end

    it 'accepts custom status code', :aggregate_failures do
      response = instance_spy(MockResponse)
      error_message = 'Service unavailable'
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      described_class.error_response(response, error_message, 503)

      expect(response).to have_received(:status=).with(503)
    end
  end

  describe '.not_found_response' do
    it 'sets 404 status with default message', :aggregate_failures do
      response = instance_spy(MockResponse)
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      described_class.not_found_response(response)

      expect(response).to have_received(:status=).with(404)
      expect(response).to have_received(:body=).with({ error: 'Endpoint not found' }.to_json)
    end

    it 'accepts custom error message', :aggregate_failures do
      response = instance_spy(MockResponse)
      custom_message = 'Resource not found'
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      described_class.not_found_response(response, custom_message)

      expect(response).to have_received(:body=).with({ error: custom_message }.to_json)
    end
  end

  describe '.bad_request_response' do
    it 'sets 400 status with error message', :aggregate_failures do
      response = instance_spy(MockResponse)
      error_message = 'Invalid parameters'
      allow(response).to receive(:status=)
      allow(response).to receive(:body=)

      described_class.bad_request_response(response, error_message)

      expect(response).to have_received(:status=).with(400)
      expect(response).to have_received(:body=).with({ error: error_message }.to_json)
    end
  end
end
