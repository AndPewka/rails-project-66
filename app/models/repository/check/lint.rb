# frozen_string_literal: true

module Repository::Check::Lint
  private

  def lint_workspace(dest)
    case repository.language
    when 'Ruby'
      rb_count = Dir.glob(File.join(dest, '**', '*.rb')).size
      append_log "\nFound #{rb_count} Ruby files under #{dest}\n"
      out, code = run_rubocop(dest)
      append_log out
      code
    when 'JavaScript'
      js_count = Dir.glob(File.join(dest, '**', '*.{js,jsx,mjs,cjs}')).size
      append_log "\nFound #{js_count} JS files under #{dest}\n"
      out, code = run_eslint(dest)
      append_log out
      code
    else
      append_log "\nUnknown language #{repository.language.inspect}, skipping lint\n"
      0
    end
  end

  def run_rubocop(dest)
    config = Rails.root.join('config/lint/.rubocop.yml')
    raise "Rubocop config not found at #{config}" unless File.exist?(config)

    cmd = [
      'bundle', 'exec', 'rubocop',
      '--no-server',
      '--force-exclusion',
      '--config', config.to_s,
      '--no-color',
      '--format', 'json',
      '--parallel',
      '.'
    ]
    run_cmd(cmd, chdir: dest)
  end

  def run_eslint(dest)
    config = eslint_config!
    args   = eslint_args(dest, config)

    if eslint_local_usable?
      run_cmd([eslint_local_path] + args)
    else
      run_cmd(['npx', '--yes', 'eslint@8.57.0'] + args, env: eslint_env)
    end
  rescue Errno::ENOENT
    raise 'ESLint требует Node.js (npm/npx). Поставь Node 18+ или добавь eslint@8 в devDependencies.'
  end

  def eslint_config!
    path = Rails.root.join('config/lint/.eslintrc.json')
    raise "ESLint config not found at #{path}" unless File.exist?(path)

    path
  end

  def eslint_args(dest, config)
    [
      '--no-eslintrc',
      '--config', config.to_s,
      '--format', 'json',
      '--ext', '.js,.jsx,.mjs,.cjs',
      '--ignore-pattern', 'node_modules/**',
      '--ignore-pattern', 'dist/**',
      dest.to_s
    ]
  end

  def eslint_local_path
    @eslint_local_path ||= Rails.root.join('node_modules/.bin/eslint').to_s
  end

  def eslint_local_usable?
    return false unless File.exist?(eslint_local_path)

    out, code = run_cmd([eslint_local_path, '-v'])
    code.zero? && out.to_s[/\d+/].to_i < 9
  end

  def eslint_env
    @eslint_env ||= {
      'NPM_CONFIG_LOGLEVEL' => 'error',
      'npm_config_loglevel' => 'error',
      'NO_UPDATE_NOTIFIER' => '1',
      'npm_config_fund' => 'false',
      'npm_config_audit' => 'false'
    }
  end
end
