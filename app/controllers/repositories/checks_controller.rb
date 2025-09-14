# frozen_string_literal: true

module Repositories
  class ChecksController < ApplicationController
    before_action :require_login

    def show
      @repository = current_user.repositories.find(params[:repository_id])
      @check = @repository.checks.find(params[:id])

      @passed = @check.exit_status.to_i.zero? && @check.error.blank?
      @entries = []
      @offenses_count = 0

      stdout = @check.stdout.to_s
      case @repository.language
      when 'Ruby' then ruby_output stdout
      when 'JavaScript' then javascript_output stdout
      else raise 'Undefined checkRepo language'
      end
    end

    def create
      repository = current_user.repositories.find(params[:repository_id])
      check = repository.checks.create!
      check.perform!
      redirect_to repository_check_path(repository, check)
    end

    private

    def ruby_output(stdout)
      json = extract_trailing_json_object(stdout)
      return unless json

      data = JSON.parse(json)
      @offenses_count = data.dig('summary', 'offense_count').to_i
      @entries = (data['files'] || []).flat_map do |f|
        (f['offenses'] || []).map do |o|
          {
            path: f['path'],
            message: o['message'],
            rule: o['cop_name'],
            loc: "#{o.dig('location', 'line')}:#{o.dig('location', 'column')}"
          }
        end
      end
    end

    def javascript_output(stdout)
      json = extract_trailing_json_array(stdout)
      return unless json

      arr = JSON.parse(json)
      @offenses_count = arr.sum { |f| f['errorCount'].to_i + f['warningCount'].to_i }
      @entries = arr.flat_map do |f|
        (f['messages'] || []).map do |m|
          {
            path: f['filePath'],
            message: m['message'],
            rule: m['ruleId'],
            loc: "#{m['line']}:#{m['column']}"
          }
        end
      end
    end

    def extract_trailing_json_object(text)
      text&.match(/\{.*\}\s*\z/m)&.to_s
    end

    def extract_trailing_json_array(text)
      text&.match(/\[\s*\{.*\}\s*\]\s*\z/m)&.to_s
    end
  end
end
