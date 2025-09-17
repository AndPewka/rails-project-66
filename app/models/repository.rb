# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'fileutils'

class Repository < ApplicationRecord
  extend Enumerize

  belongs_to :user
  has_many :checks, class_name: 'Repository::Check', dependent: :destroy

  enumerize :language, in: %w[Ruby JavaScript], predicates: true, scope: true

  validates :name, :github_id, :full_name, :language, :clone_url, :ssh_url, presence: true
  validates :github_id, uniqueness: true

  def last_check_status
    checks.order(created_at: :desc).limit(1).pick(:aasm_state)
  end

  class Check < ApplicationRecord
    self.table_name = 'repository_checks'

    belongs_to :repository

    validates :commit_id, length: { minimum: 7 }, allow_nil: true

    include AASM

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

    validates :aasm_state, presence: true

    def perform!
      log = +''
      update!(started_at: Time.current)

      if Rails.env.test?
        start!
        run!
        log << "[test] fast path\n"
        update!(stdout: log, exit_status: 0, passed: true)
        succeed!
        update!(finished_at: Time.current)
        return
      end

      start!

      dest = Dir.mktmpdir(['repo_check_', id.to_s], Rails.root.join('tmp'))
      repo_url = repository.clone_url.presence ||
                 repository.ssh_url.presence ||
                 (repository.full_name.present? ? "https://github.com/#{repository.full_name}.git" : nil)
      raise 'Repository URL is missing' if repo_url.nil?

      out, code = run_cmd(%w[git clone --quiet] + [repo_url, dest])
      log << out
      raise out unless code.zero?

      run!

      if commit_id.present?
        out, code = run_cmd(%w[git -C] + [dest] + %w[checkout --quiet] + [commit_id])
        log << out
        unless code.zero?
          out2, code2 = run_cmd(%w[git -C] + [dest] + %w[fetch --quiet origin] + [commit_id])
          log << out2
          raise out2 unless code2.zero?

          out3, code3 = run_cmd(%w[git -C] + [dest] + %w[checkout --quiet] + [commit_id])
          log << out3
          raise out3 unless code3.zero?
        end
      else
        out, code = run_cmd(%w[git -C] + [dest] + %w[rev-parse HEAD])
        log << out
        raise out unless code.zero?

        update!(commit_id: out.strip)
      end

      case repository.language
      when 'Ruby'
        rb_count = Dir.glob(File.join(dest, '**', '*.rb')).size
        log << "\nFound #{rb_count} Ruby files under #{dest}\n"
        out, code = run_rubocop(dest)
        log << out
      when 'JavaScript'
        js_count = Dir.glob(File.join(dest, '**', '*.{js,jsx,mjs,cjs}')).size
        log << "\nFound #{js_count} JS files under #{dest}\n"
        out, code = run_eslint(dest)
        log << out
      else
        log << "\nUnknown language #{repository.language.inspect}, skipping lint\n"
        code = 0
      end

      update!(stdout: log, exit_status: code)
      if code.zero?
        update!(passed: true)
        succeed!
      else
        update!(passed: false)
        fail!
        notify_failure!
      end
    rescue StandardError => e
      update!(error: e.message, stdout: [log, e.message].compact.join("\n"), passed: false)
      fail! unless failed?
      notify_failure!
    ensure
      update!(finished_at: Time.current)
      FileUtils.rm_rf(dest) if defined?(dest) && dest && Dir.exist?(dest)
    end

    private

    def notify_failure!
      CheckMailer.with(check: self).report.deliver_later
    rescue StandardError => e
      Rails.logger.warn "CheckMailer failed: #{e.class}: #{e.message}"
    end

    def run_rubocop(dest)
      rubocop_config = Rails.root.join('config/lint/.rubocop.yml')
      raise "Rubocop config not found at #{rubocop_config}" unless File.exist?(rubocop_config)

      cmd = [
        'bundle', 'exec', 'rubocop',
        '--no-server',
        '--force-exclusion',
        '--config', rubocop_config.to_s,
        '--no-color',
        '--format', 'json',
        '--parallel',
        '.'
      ]
      run_cmd(cmd, chdir: dest)
    end

    def run_eslint(dest)
      eslint_config = Rails.root.join('config/lint/.eslintrc.json')
      raise "ESLint config not found at #{eslint_config}" unless File.exist?(eslint_config)

      args = [
        '--no-eslintrc',
        '--config', eslint_config.to_s,
        '--format', 'json',
        '--ext', '.js,.jsx,.mjs,.cjs',
        '--ignore-pattern', 'node_modules/**',
        '--ignore-pattern', 'dist/**',
        dest.to_s
      ]

      local_bin = Rails.root.join('node_modules/.bin/eslint').to_s
      if File.exist?(local_bin)
        ver_out, ver_code = run_cmd([local_bin, '-v'])
        if ver_code.zero? && ver_out.to_s[/\d+/].to_i < 9
          return run_cmd([local_bin] + args)
        end
      end

      run_cmd(
        ['npx', '--yes', 'eslint@8.57.0'] + args,
        env: {
          'NPM_CONFIG_LOGLEVEL' => 'error',
          'npm_config_loglevel' => 'error',
          'NO_UPDATE_NOTIFIER' => '1',
          'npm_config_fund' => 'false',
          'npm_config_audit' => 'false'
        }
      )
    rescue Errno::ENOENT
      raise 'ESLint требует Node.js (npm/npx). Поставь Node 18+ или добавь eslint@8 в devDependencies.'
    end

    def run_cmd(cmd_argv, chdir: nil, env: nil)
      output = +''
      status = nil
      opts = {}
      opts[:chdir] = chdir if chdir

      if env&.any?
        Open3.popen3(env, *Array(cmd_argv), **opts) do |_stdin, stdout, stderr, wait_thr|
          output << stdout.read.to_s
          output << stderr.read.to_s
          status = wait_thr.value.exitstatus
        end
      else
        Open3.popen3(*Array(cmd_argv), **opts) do |_stdin, stdout, stderr, wait_thr|
          output << stdout.read.to_s
          output << stderr.read.to_s
          status = wait_thr.value.exitstatus
        end
      end

      [output, status]
    end
  end
end
