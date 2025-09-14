# frozen_string_literal: true

class CheckMailer < ApplicationMailer
  default from: ENV.fetch('SMTP_USERNAME', 'no-reply@example.com')

  def report
    @check = params[:check]
    @repository = @check.repository

    @short_sha  = @check.commit_id.to_s.first(7).presence || '-'
    @commit_url = if @check.commit_id.present?
                    "https://github.com/#{@repository.full_name}/commit/#{@check.commit_id}"
                  end

    @check_url  = Rails.application.routes.url_helpers.repository_check_url(@repository, @check)

    mail to: 'andpewka@mail.ru',
         subject: I18n.t('check_mailer.report.subject',
                         repo: @repository.full_name,
                         sha: @short_sha)
  end
end
