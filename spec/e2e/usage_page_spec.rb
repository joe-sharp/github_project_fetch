# frozen_string_literal: true

#
# E2E browser tests for the usage page served at /api?format=html.
# See api_integration_spec.rb for how to run these.

require 'spec_helper'
require 'selenium-webdriver'

RSpec.describe 'Usage page', :e2e do
  let(:driver) do
    options = Selenium::WebDriver::Chrome::Options.new
    %w[--headless --no-sandbox --disable-dev-shm-usage --disable-gpu --window-size=1280,900].each do |arg|
      options.add_argument(arg)
    end
    Selenium::WebDriver.for(:chrome, options: options)
  end
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 20, interval: 0.25) }

  before { driver.get(E2eClient.browser_url('/api?format=html')) }

  after do
    if RSpec.current_example.exception
      FileUtils.mkdir_p('tmp/screenshots')
      name = RSpec.current_example.full_description.gsub(/\W+/, '_')[0, 80]
      driver.save_screenshot("tmp/screenshots/#{name}.png")
    end
    driver.quit
  end

  def health_text
    driver.find_element(id: 'health').text
  end

  def submit(username)
    field = driver.find_element(id: 'username')
    field.clear
    field.send_keys(username)
    driver.find_element(id: 'go').click
  end

  it 'renders the guide', :aggregate_failures do
    expect(driver.title).not_to be_empty
    expect(driver.find_element(id: 'tryForm')).to be_displayed
    expect(driver.find_element(id: 'username')[:value]).to eq('octocat')
  end

  it 'shows the API as healthy' do
    wait.until { health_text.start_with?('API healthy') }

    expect(health_text).to match(/API healthy · \d+ GitHub calls left/)
  end

  it 'fills the curl examples with the page origin', :aggregate_failures do
    curls = driver.find_elements(css: '[data-curl]').map(&:text)

    expect(curls).not_to be_empty
    expect(curls).to all(start_with("curl '#{E2eClient.base_url}/api"))
  end

  it 'fetches repositories for the default user', :aggregate_failures do
    driver.find_element(id: 'go').click
    wait.until { driver.find_elements(css: '#result .repo').any? }

    expect(driver.find_element(css: '#result .msg').text).to include('public repositories for octocat')
    expect(driver.find_elements(css: '#result .repo .chip')).not_to be_empty
    expect(driver.find_element(css: '#result details summary').text).to eq('Raw JSON')
  end

  it 'shows an error for an invalid username' do
    submit('a<b')
    wait.until { driver.find_elements(css: '#result .msg.err').any? }

    expect(driver.find_element(css: '#result .msg.err').text).not_to be_empty
  end
end
