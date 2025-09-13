# frozen_string_literal: true

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning = true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
           ENV.fetch('GITHUB_CLIENT_ID'),
           ENV.fetch('GITHUB_CLIENT_SECRET'),
           scope: ENV['GITHUB_SCOPES'] || 'user,public_repo,admin:repo_hook'
end
