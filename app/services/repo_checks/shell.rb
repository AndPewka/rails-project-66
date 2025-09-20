# frozen_string_literal: true

require 'open3'
require 'fileutils'

module RepoChecks
  module Shell
    private

    def run_cmd(cmd_argv, chdir: nil, env: nil)
      opts = {}
      opts[:chdir] = chdir if chdir
      argv = Array(cmd_argv)

      if env.present?
        popen_capture_with_env(env, *argv, **opts)
      else
        popen_capture(*argv, **opts)
      end
    end

    def popen_capture(*argv, **opts)
      output = +''
      status = nil
      Open3.popen3(*argv, **opts) do |_stdin, stdout, stderr, wait_thr|
        output << stdout.read.to_s
        output << stderr.read.to_s
        status = wait_thr.value.exitstatus
      end
      [output, status]
    end

    def popen_capture_with_env(env, *argv, **opts)
      output = +''
      status = nil
      Open3.popen3(env, *argv, **opts) do |_stdin, stdout, stderr, wait_thr|
        output << stdout.read.to_s
        output << stderr.read.to_s
        status = wait_thr.value.exitstatus
      end
      [output, status]
    end

    def cleanup_dir(dest)
      FileUtils.rm_rf(dest) if dest && Dir.exist?(dest)
    end
  end
end
