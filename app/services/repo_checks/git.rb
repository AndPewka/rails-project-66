# frozen_string_literal: true

module RepoChecks
  module Git
    private

    def repo_url!
      url = repository.clone_url.presence ||
            repository.ssh_url.presence ||
            (repository.full_name.present? ? "https://github.com/#{repository.full_name}.git" : nil)
      raise 'Repository URL is missing' if url.nil?

      url
    end

    def clone_repo!(dest)
      out, code = run_cmd(%w[git clone --quiet] + [repo_url!, dest])
      append_log out
      raise out unless code.zero?
    end

    def checkout_target_commit!(dest)
      return checkout_present_commit!(dest) if commit_id.present?

      out, code = run_cmd(%w[git -C] + [dest] + %w[rev-parse HEAD])
      append_log out
      raise out unless code.zero?

      update!(commit_id: out.strip)
    end

    def checkout_present_commit!(dest)
      out, code = run_cmd(%w[git -C] + [dest] + %w[checkout --quiet] + [commit_id])
      append_log out
      return if code.zero?

      out2, code2 = run_cmd(%w[git -C] + [dest] + %w[fetch --quiet origin] + [commit_id])
      append_log out2
      raise out2 unless code2.zero?

      out3, code3 = run_cmd(%w[git -C] + [dest] + %w[checkout --quiet] + [commit_id])
      append_log out3
      raise out3 unless code3.zero?
    end
  end
end
