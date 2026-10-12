# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'api/projects.rb', :aggregate_failures, type: :handler do
  let(:service) { instance_double(GithubRepoFetcher::ProjectService) }
  let(:result) { { username: 'octocat', projects_count: 0, projects: [] } }

  before do
    GithubRepoFetcher::SecurityService::RATE_LIMITER[:requests].clear
    allow(GithubRepoFetcher::ProjectService).to receive(:new).and_return(service)
  end

  after do
    GithubRepoFetcher::SecurityService::RATE_LIMITER[:requests].clear
  end

  it 'returns the user projects with 10 minute caching' do
    allow(service).to receive(:fetch_user_projects).with('octocat').and_return(result)

    response = run_handler('projects', path: '/api/projects', query: { 'username' => 'octocat' })

    expect(response.status).to eq(200)
    expect(response.json).to eq('username' => 'octocat', 'projects_count' => 0, 'projects' => [])
    expect(response['Cache-Control']).to eq('s-maxage=600, stale-while-revalidate=1200')
  end

  it 'sends CORS headers' do
    allow(service).to receive(:fetch_user_projects).and_return(result)

    response = run_handler('projects', query: { 'username' => 'octocat' })

    expect(response['Access-Control-Allow-Origin']).to eq('*')
  end

  it 'returns 400 when the username is missing' do
    response = run_handler('projects', path: '/api/projects')

    expect(response.status).to eq(400)
    expect(response.json['error']).to match(/Username parameter is required/)
  end

  it 'returns 400 for an unsafe username' do
    response = run_handler('projects', query: { 'username' => 'a<b' })

    expect(response.status).to eq(400)
  end

  it 'returns 400 when the service raises ArgumentError' do
    allow(service).to receive(:fetch_user_projects).and_raise(ArgumentError, 'bad input')

    response = run_handler('projects', query: { 'username' => 'octocat' })

    expect([response.status, response.json]).to eq([400, { 'error' => 'bad input' }])
  end

  it 'returns 500 for other failures such as an unknown user' do
    allow(service).to receive(:fetch_user_projects).and_raise(StandardError, "User 'ghost' not found")

    response = run_handler('projects', query: { 'username' => 'ghost' })

    expect([response.status, response.json]).to eq([500, { 'error' => "User 'ghost' not found" }])
  end

  it 'answers CORS preflight without calling GitHub' do
    allow(service).to receive(:fetch_user_projects)

    response = run_handler('projects', method: 'OPTIONS')

    expect(service).not_to have_received(:fetch_user_projects)
    expect(response.status).to eq(200)
  end
end
