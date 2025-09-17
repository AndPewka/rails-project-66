# frozen_string_literal: true

if Rails.env.test?
  class FakeGithubClient
    Repo = Struct.new(:id, :name, :full_name, :language, :clone_url, :ssh_url, keyword_init: true)
    Hook = Struct.new(:id, :config, keyword_init: true)

    def initialize(**_opts); end

    def repos
      []
    end

    def repo(identifier)
      if identifier.to_s.match?(/\A\d+\z/)
        id        = identifier.to_i
        full_name = "hexlet-repos/#{id}"
        name      = "repo-#{id}"
      else
        full_name = identifier.to_s
        name      = full_name.split('/').last || full_name
        id        = 0
      end

      Repo.new(
        id: id,
        name: name,
        full_name: full_name,
        language: 'Ruby',
        clone_url: "https://github.com/#{full_name}.git",
        ssh_url: "git@github.com:#{full_name}.git"
      )
    end

    def create_hook(_full_name, _type, config, **_options)
      Hook.new(id: 1, config: config)
    end
  end

  ApplicationContainer.register(
    :github_client,
    ->(**opts) { FakeGithubClient.new(**opts) }
  )
else
  ApplicationContainer.register(
    :github_client,
    ->(**opts) { Octokit::Client.new(**opts) }
  )
end
