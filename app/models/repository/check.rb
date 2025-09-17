# frozen_string_literal: true

class Repository::Check < ApplicationRecord
  self.table_name = 'repository_checks'

  belongs_to :repository

  validates :commit_id, length: { minimum: 7 }, allow_nil: true
  validates :aasm_state, presence: true

  include AASM
  include Repository::Check::Git
  include Repository::Check::Lint
  include Repository::Check::Shell
  include Repository::Check::Notifications

  aasm column: :aasm_state do
    state :queued, initial: true
    state :cloning
    state :running
    state :finished
    state :failed

    event :start do
      transitions from: :queued,  to: :cloning
    end

    event :run do
      transitions from: :cloning, to: :running
    end

    event :succeed do
      transitions from: :running, to: :finished
    end

    event :fail do
      transitions from: %i[queued cloning running], to: :failed
    end
  end

  alias_attribute :state, :aasm_state

  def perform!
    @log = +''
    update!(started_at: Time.current)

    return fast_path! if Rails.env.test?

    start!
    dest = make_workspace
    begin
      clone_repo!(dest)
      run!
      checkout_target_commit!(dest)
      code = lint_workspace(dest)
      finalize!(code)
    rescue StandardError => e
      handle_failure!(e)
    ensure
      update!(finished_at: Time.current)
      cleanup_dir(dest)
    end
  end

  private

  def fast_path!
    start!
    run!
    append_log "[test] fast path\n"
    update!(stdout: @log, exit_status: 0, passed: true)
    succeed!
    update!(finished_at: Time.current)
  end

  def make_workspace
    Dir.mktmpdir(['repo_check_', id.to_s], Rails.root.join('tmp'))
  end

  def finalize!(code)
    update!(stdout: @log, exit_status: code)
    if code.zero?
      update!(passed: true)
      succeed!
    else
      update!(passed: false)
      fail!
      notify_failure!
    end
  end

  def handle_failure!(error)
    update!(error: error.message, stdout: [@log, error.message].compact.join("\n"), passed: false)
    fail! unless failed?
    notify_failure!
  end

  def append_log(str)
    @log << str.to_s
  end
end
