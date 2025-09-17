# frozen_string_literal: true

module Api
  class ChecksController < ActionController::API
    protect_from_forgery with: :null_session if respond_to?(:protect_from_forgery)

    def create
      event = request.headers['X-GitHub-Event'].to_s

      if event.present? && event != 'push'
        head :accepted
        return
      end

      payload   = params.to_unsafe_h
      repo_data = payload['repository'] || {}

      github_id  = repo_data['id']
      full_name  = repo_data['full_name']
      commit_sha = payload['after'] || payload.dig('head_commit', 'id')

      repo =
        if github_id.present?
          Repository.find_by!(github_id: github_id)
        elsif full_name.present?
          Repository.find_by!(full_name: full_name)
        else
          raise ActiveRecord::RecordNotFound
        end

      check = repo.checks.create!(commit_id: commit_sha)
      check.perform!

      render json: { id: check.id, state: check.state, exit: check.exit_status }, status: :created
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'repository_not_found' }, status: :not_found
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
