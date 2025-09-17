# frozen_string_literal: true

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
end
