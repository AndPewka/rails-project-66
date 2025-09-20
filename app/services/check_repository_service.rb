# frozen_string_literal: true

class CheckRepositoryService
  include RepoChecks::Git
  include RepoChecks::Lint
  include RepoChecks::Shell
  include RepoChecks::Notifications

  def initialize(check)
    @check = check
  end

  def call
    @log = +''
    check.update!(started_at: Time.current)

    return fast_path! if Rails.env.test?

    check.start!
    dest = make_workspace
    begin
      clone_repo!(dest)
      check.run!
      checkout_target_commit!(dest)
      code = lint_workspace(dest)
      finalize!(code)
    rescue StandardError => e
      handle_failure!(e)
    ensure
      check.update!(finished_at: Time.current)
      cleanup_dir(dest)
    end

    check
  end

  private

  attr_reader :check

  delegate :repository, :commit_id, :update!, :failed?, :start!, :run!, :succeed!, :fail!, to: :check

  def fast_path!
    check.start!
    check.run!
    append_log "[test] fast path\n"
    check.update!(stdout: @log, exit_status: 0, passed: true)
    check.succeed!
    check.update!(finished_at: Time.current)
    check
  end

  def make_workspace
    Dir.mktmpdir(['repo_check_', check.id.to_s], Rails.root.join('tmp'))
  end

  def finalize!(code)
    check.update!(stdout: @log, exit_status: code)
    if code.zero?
      check.update!(passed: true)
      check.succeed!
    else
      check.update!(passed: false)
      check.fail!
      notify_failure!
    end
  end

  def handle_failure!(error)
    check.update!(error: error.message,
                  stdout: [@log, error.message].compact.join("\n"),
                  passed: false)
    check.fail! unless check.failed?
    notify_failure!
  end

  def append_log(str)
    @log << str.to_s
  end
end
