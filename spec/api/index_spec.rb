# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'api/index.rb', :aggregate_failures, type: :handler do
  let(:browser_accept) { { 'accept' => 'text/html,application/xhtml+xml,*/*;q=0.8' } }

  it 'serves JSON usage to clients that do not ask for HTML' do
    response = run_handler('index', path: '/api')

    expect(response.status).to eq(200)
    expect(response['Content-Type']).to eq('application/json')
    expect(response.json).to include('name', 'version', 'endpoints', 'parameters', 'examples', 'limits', 'errors')
  end

  it 'serves the HTML guide to browsers' do
    response = run_handler('index', path: '/', headers: browser_accept)

    expect(response.status).to eq(200)
    expect(response['Content-Type']).to eq('text/html; charset=utf-8')
    expect(response.body).to start_with('<!DOCTYPE html>')
  end

  it 'serves HTML for ?format=html without an Accept header' do
    response = run_handler('index', query: { 'format' => 'html' })

    expect(response['Content-Type']).to eq('text/html; charset=utf-8')
  end

  it 'lets ?format=json override a browser Accept header' do
    response = run_handler('index', query: { 'format' => 'json' }, headers: browser_accept)

    expect(response['Content-Type']).to eq('application/json')
  end

  it 'varies on Accept and caches for an hour' do
    response = run_handler('index')

    expect(response['Vary']).to eq('Accept')
    expect(response['Cache-Control']).to eq('s-maxage=3600, stale-while-revalidate=7200')
  end

  it 'sends CORS headers' do
    response = run_handler('index')

    expect(response['Access-Control-Allow-Origin']).to eq('*')
  end

  it 'answers CORS preflight with an empty 200' do
    response = run_handler('index', method: 'OPTIONS')

    expect([response.status, response.body]).to eq([200, ''])
  end

  it 'returns 404 for unknown paths' do
    response = run_handler('index', path: '/nope')

    expect([response.status, response.json]).to eq([404, { 'error' => 'Endpoint not found' }])
  end
end
