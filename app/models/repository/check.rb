# frozen_string_literal: true

class Repository::Check < ApplicationRecord
  self.table_name = 'repository_checks'

  belongs_to :repository

  validates :commit_id, length: { minimum: 7 }, allow_nil: true
  validates :aasm_state, presence: true

  include AASM

  aasm column: :aasm_state do
    state :queued, initial: true
    state :cloning, :running, :finished, :failed

    event :start do
      transitions from: :queued, to: :cloning
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
end
