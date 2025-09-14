# frozen_string_literal: true

ApplicationContainer.register(
  :github_client,
  ->(**opts) { Octokit::Client.new(**opts) }
)
