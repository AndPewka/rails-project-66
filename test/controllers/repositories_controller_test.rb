# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'omniauth'
require 'omniauth/auth_hash'
require 'dry/container/stub'

Repo = Struct.new(:id, :name, :full_name, :language, :clone_url, :ssh_url, keyword_init: true)

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  def sign_in(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: 'github',
      uid: 'u1',
      info: { email: user.email, nickname: user.nickname, name: user.name, image: nil },
      credentials: { token: user.token.presence || 'test-token' }
    )
    get '/auth/github/callback'
  end

  test 'index shows only current user repositories' do
    user = users(:one)
    other = users(:two)
    sign_in(user)

    user.repositories.create!(github_id: 10_001, name: 'mine-1', full_name: 'me/mine-1', language: 'Ruby', clone_url: 'https://ex/m1', ssh_url: 'git@ex:m1.git')
    user.repositories.create!(github_id: 10_002, name: 'mine-2', full_name: 'me/mine-2', language: 'Ruby', clone_url: 'https://ex/m2', ssh_url: 'git@ex:m2.git')
    other.repositories.create!(github_id: 10_003, name: 'other', full_name: 'you/other', language: 'Ruby', clone_url: 'https://ex/o', ssh_url: 'git@ex:o.git')

    get repositories_path
    assert_response :success

    assert_select 'table tbody tr', 2
    assert_select 'td', text: 'mine-1'
    assert_select 'td', text: 'mine-2'
    assert_select 'td', text: 'other', count: 0
  end

  test 'create adds a Ruby repository by full_name' do
    user = users(:one)
    sign_in(user)

    fake = Minitest::Mock.new
    fake.expect :repo, Repo.new(
      id: 99_001, name: 'rails', full_name: 'me/rails', language: 'Ruby',
      clone_url: 'https://github.com/me/rails.git',
      ssh_url: 'git@github.com:me/rails.git'
    ), ['me/rails']
    fake.expect :create_hook, true do |full_name, hook, config, **opts|
      full_name == 'me/rails' && hook == 'web' && config.is_a?(Hash) &&
        config[:url].to_s.include?('/api/checks') && opts[:events] == ['push'] && opts[:active] == true
    end

    ApplicationContainer.stub(:github_client, ->(**) { fake }) do
      assert_difference -> { user.repositories.count }, +1 do
        post repositories_path, params: { github_id: 'me/rails' }
      end
    end

    follow_redirect!
    assert_response :success

    created = user.repositories.find_by(github_id: 99_001)
    assert created.present?
    assert_equal 'me/rails', created.full_name
  end

  test 'create rejects non-Ruby repository' do
    user = users(:one)
    sign_in(user)

    fake = Minitest::Mock.new
    fake.expect :repo, Repo.new(
      id: 99_002, name: 'node', full_name: 'me/node', language: 'Python',
      clone_url: 'https://github.com/me/node.git',
      ssh_url: 'git@github.com:me/node.git'
    ), ['me/node']

    ApplicationContainer.stub(:github_client, ->(**) { fake }) do
      assert_no_difference -> { user.repositories.count } do
        post repositories_path, params: { github_id: 'me/node' }
      end
    end

    assert_redirected_to new_repository_path
  end

  test 'new lists only Ruby repositories from GitHub' do
    user = users(:one)
    sign_in(user)

    ruby1 = Repo.new(id: 1001, name: 'r1', full_name: 'me/r1', language: 'Ruby', clone_url: '', ssh_url: '')
    js = Repo.new(id: 1002, name: 'j1', full_name: 'me/j1', language: 'Python', clone_url: '', ssh_url: '')
    ruby2 = Repo.new(id: 1003, name: 'r2', full_name: 'me/r2', language: 'Ruby', clone_url: '', ssh_url: '')

    fake = Minitest::Mock.new
    fake.expect :repos, [ruby1, js, ruby2]

    ApplicationContainer.stub(:github_client, ->(**) { fake }) do
      get new_repository_path
    end

    assert_response :success
    assert_select 'select[name=github_id] option', 2
    assert_select 'option', %r{me/r1}
    assert_select 'option', %r{me/r2}
    assert_select 'option', text: %r{me/j1}, count: 0
  end

  test 'create handles invalid identifier error' do
    user = users(:one)
    sign_in(user)

    fake = Object.new
    def fake.repo(_) = raise(Octokit::InvalidRepository)

    ApplicationContainer.stub(:github_client, ->(**) { fake }) do
      post repositories_path, params: { github_id: 'bad-format' }
    end

    assert_redirected_to new_repository_path
  end
end
