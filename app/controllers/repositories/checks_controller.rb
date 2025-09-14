# frozen_string_literal: true

module Repositories
  class ChecksController < ApplicationController
    before_action :require_login

    def show
      @repository = current_user.repositories.find(params[:repository_id])
      @check = @repository.checks.find(params[:id])
    end

    def create
      repository = current_user.repositories.find(params[:repository_id])
      check = repository.checks.create!
      check.perform!
      redirect_to repository_check_path(repository, check)
    end
  end
end
