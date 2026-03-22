# frozen_string_literal: true

require 'rspec'
require 'rspec/collection_matchers'
require 'rest-client'
require 'securerandom'
require 'time'
require "capybara/rspec"
require "selenium/webdriver"

require_relative 'support/kubectl'
require_relative 'support/http'
require_relative 'support/file'
require_relative 'support/config'
require_relative 'support/util'

RSpec.configure do |conf|
  include HttpHelpers
  include FileHelpers
  include UtilHelpers
  include Kubectl # provides kubectl command running

  conf.filter_run focus: true
  conf.run_all_when_everything_filtered = true
  conf.formatter = :documentation

  Capybara.default_driver = :headless_chrome
  Capybara.javascript_driver = :headless_chrome
  Capybara.default_max_wait_time = 5
  Capybara.disable_animation = true
  Capybara.register_driver :headless_chrome do |app|
    browser_options = Selenium::WebDriver::Options.chrome(args: [
      "--headless=new",
      "allow-insecure-localhost",  # Ignore TLS/SSL errors on localhost
      "ignore-certificate-errors", # Ignore certificate related errors
      "headless",
      "disable-gpu",
      "disable-dev-shm-usage",
      "no-sandbox"
    ])
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end
end

RSpec::Matchers.define :be_a_404 do |expected|
  match do |response| # actual
    expect(response.code).to eq 404
  end
end

RSpec::Matchers.define :be_a_200 do |expected|
  match do |response| # actual
    expect(response.code).to eq 200
  end
end

RSpec::Matchers.define :include_regex do |regex|
  match do |actual|
    actual.find { |str| str =~ regex }
  end
end
