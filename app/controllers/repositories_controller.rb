# frozen_string_literal: true

class RepositoriesController < ApplicationController
  before_action :require_login, only: %i[new create]

  def index
    @repositories = current_user ? current_user.repositories.order(:name) : []
  end

  def show
    @repository = current_user.repositories.find(params[:id])
    @checks = @repository.checks.order(created_at: :desc).limit(20)
  end

  def new
    client = github_client
    @github_repos = client.repos.select { |r| r.language == 'Ruby' }
  rescue Octokit::Unauthorized
    redirect_to root_path, alert: t('.github_auth_error')
  end

  def create
    client = github_client

    raw = params[:github_id] || params.dig(:repository, :github_id)
    raise ArgumentError, 'missing repo param' if raw.blank?

    identifier = raw.to_s.match?(/\A\d+\z/) ? raw.to_i : raw
    gh_repo = client.repo(identifier)

    unless gh_repo.language == 'Ruby'
      redirect_to new_repository_path, alert: t('.only_ruby') and return
    end

    repo = current_user.repositories.find_or_initialize_by(github_id: gh_repo.id)
    repo.assign_attributes(
      name: gh_repo.name,
      full_name: gh_repo.full_name,
      language: gh_repo.language,
      clone_url: gh_repo.clone_url,
      ssh_url: gh_repo.ssh_url
    )

    if repo.save
      redirect_to repositories_path, notice: t('.created')
    else
      redirect_to new_repository_path, alert: repo.errors.full_messages.to_sentence
    end
  rescue Octokit::NotFound, Octokit::InvalidRepository
    redirect_to new_repository_path, alert: t('.not_found')
  end

  private

  def github_client
    @github_client ||= ApplicationContainer[:github_client].call(
      access_token: current_user.token,
      auto_paginate: true
    )
  end
end
