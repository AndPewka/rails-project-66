# frozen_string_literal: true

source 'https://rubygems.org'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.2.2'
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'
# Use sqlite3 as the database for Active Record
# gem 'sqlite3', '>= 1.4'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem 'jsbundling-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem 'cssbundling-rails'
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

gem 'slim-rails'

gem 'enumerize'
gem 'octokit'

gem 'aasm'

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw x64_mingw mswin jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

gem 'omniauth'
gem 'omniauth-github'
gem 'omniauth-rails_csrf_protection'

gem 'dry-auto_inject'
gem 'dry-container'

gem 'rubocop'
gem 'rubocop-rails-omakase'


# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"
group :production do
  gem 'pg'
end

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw], require: 'debug/prelude'
  gem 'dotenv-rails'

  gem 'sqlite3', '~> 1.4'

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false
  gem 'faker'
  gem 'slim_lint'

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'minitest-power_assert'
  gem 'selenium-webdriver'
  gem 'webmock'
end
