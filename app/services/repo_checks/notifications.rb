# frozen_string_literal: true

module RepoChecks
  module Notifications
    private

    def notify_failure!
      CheckMailer.with(check: self).report.deliver_later
    rescue StandardError => e
      Rails.logger.warn "CheckMailer failed: #{e.class}: #{e.message}"
    end
  end
end
