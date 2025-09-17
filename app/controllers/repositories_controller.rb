# frozen_string_literal: true

class RepositoriesController < ApplicationController
  SUPPORTED_LANGUAGES = %w[Ruby JavaScript].freeze
  before_action :require_login, only: %i[new create]

  def index
    @repositories = current_user ? current_user.repositories.order(:name) : []
  end

  def show
    @repository = current_user.repositories.find(params[:id])
    @checks     = @repository.checks.order(created_at: :desc).limit(20)
  end

  def new
    client = github_client
    @github_repos = client.repos.select { |r| supported_language?(r.language) }
  rescue Octokit::Unauthorized
    redirect_to root_path, alert: t('.github_auth_error')
  rescue StandardError => e
    Rails.logger.info "GitHub API unavailable (#{e.class}): #{e.message}"
    @github_repos = []
  end

  def create
    perform_create!
  rescue Octokit::NotFound, Octokit::InvalidRepository
    redirect_to new_repository_path, alert: t('.not_found')
  rescue StandardError => e
    Rails.logger.info "GitHub API unavailable (#{e.class}): #{e.message}"
    redirect_to new_repository_path, alert: t('.not_found')
  end

  private

  def perform_create!
    client = github_client
    identifier = repo_identifier!

    gh_repo = client.repo(identifier)
    return redirect_to(new_repository_path, alert: t('.only_supported')) unless supported_language?(gh_repo.language)

    repo = build_repo_from_github(gh_repo)
    if repo.save
      install_github_webhook!(client, gh_repo.full_name)
      redirect_to repositories_path, notice: t('.created')
    else
      redirect_to new_repository_path, alert: repo.errors.full_messages.to_sentence
    end
  end

  def repo_identifier!
    raw = params[:github_id] || params.dig(:repository, :github_id)
    raise ArgumentError, 'missing repo param' if raw.blank?

    raw.to_s.match?(/\A\d+\z/) ? raw.to_i : raw
  end

  def supported_language?(lang)
    SUPPORTED_LANGUAGES.include?(lang)
  end

  def build_repo_from_github(gh_repo)
    current_user.repositories.find_or_initialize_by(github_id: gh_repo.id).tap do |repo|
      repo.name = gh_repo.name
      repo.full_name = gh_repo.full_name
      repo.language = gh_repo.language
      repo.clone_url = gh_repo.clone_url
      repo.ssh_url = gh_repo.ssh_url
    end
  end

  def install_github_webhook!(client, full_name)
    return if Rails.env.test?
    return if Rails.application.routes.default_url_options[:host].blank?

    url_helpers = Rails.application.routes.url_helpers
    callback_url = url_helpers.api_checks_url

    config  = { url: callback_url, content_type: 'json', insecure_ssl: '0' }
    options = { events: ['push'], active: true }

    client.create_hook(full_name, 'web', config, **options)
  rescue Octokit::UnprocessableEntity => e
    Rails.logger.info "Webhook already exists for #{full_name}: #{e.message}"
  rescue Octokit::Forbidden => e
    Rails.logger.warn "No permission to create webhook for #{full_name}: #{e.message}"
  rescue Octokit::Unauthorized, Octokit::NotFound => e
    Rails.logger.warn "Cannot create webhook for #{full_name}: #{e.class} #{e.message}"
  end

  def github_client
    @github_client ||= ApplicationContainer[:github_client].call(
      access_token: current_user.token,
      auto_paginate: true
    )
  end
end
