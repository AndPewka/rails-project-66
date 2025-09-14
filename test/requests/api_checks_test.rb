# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ApiChecksTest < ActionDispatch::IntegrationTest
  fixtures :users

  def with_fake_open3(&)
    status = Struct.new(:exitstatus).new(0)
    wait_thr = Struct.new(:value).new(status)

    Open3.stub(:popen3, lambda { |*args, **_opts, &blk|
      cmd = args.flatten.join(' ')
      stdout_str = cmd.include?('rev-parse HEAD') ? "503d6af\n" : ''
      stdout = StringIO.new(stdout_str)
      stderr = StringIO.new('')
      blk.call(nil, stdout, stderr, wait_thr)
      nil
    }, &)
  end

  def setup_repo(language: 'JavaScript')
    user = users(:one)
    user.repositories.create!(
      github_id: 12_345_678,
      name: 'rails-project-66',
      full_name: 'AndPewka/rails-project-66',
      language: language,
      clone_url: 'https://example.com/repo.git',
      ssh_url: 'git@example.com:repo.git'
    )
  end

  test 'push webhook creates check, runs it and passes (exit 0)' do
    repo = setup_repo(language: 'JavaScript')

    payload = {
      repository: {
        id: repo.github_id,
        full_name: repo.full_name,
        clone_url: repo.clone_url,
        ssh_url: repo.ssh_url
      },
      after: '503d6af'
    }

    with_fake_open3 do
      assert_difference -> { repo.checks.count }, +1 do
        post api_checks_path,
             params: payload.to_json,
             headers: {
               'CONTENT_TYPE' => 'application/json',
               'HTTP_X_GITHUB_EVENT' => 'push'
             }
      end
    end

    assert_response :created

    check = repo.checks.order(:created_at).last
    assert { check.commit_id&.start_with?('503d6af') }
    assert_equal 'finished', check.state
    assert_equal 0, check.exit_status
  end

  test 'non-push events are accepted and ignored' do
    repo = setup_repo

    payload = { repository: { id: repo.github_id }, after: '503d6af' }

    assert_no_difference -> { repo.checks.count } do
      post api_checks_path,
           params: payload.to_json,
           headers: {
             'CONTENT_TYPE' => 'application/json',
             'HTTP_X_GITHUB_EVENT' => 'issues'
           }
    end

    assert_response :accepted
  end

  test '404 when repository is not found' do
    payload = { repository: { id: 999_999 }, after: '503d6af' }

    post api_checks_path,
         params: payload.to_json,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'HTTP_X_GITHUB_EVENT' => 'push'
         }

    assert_response :not_found
  end
end
