# frozen_string_literal: true

class RenameStateToAasmStateAndAddPassedToRepositoryChecks < ActiveRecord::Migration[7.2]
  def up
    if column_exists?(:repository_checks, :state)
      rename_column :repository_checks, :state, :aasm_state
    end

    return if column_exists?(:repository_checks, :passed)

    add_column :repository_checks, :passed, :boolean, null: false, default: false
  end

  def down
    if column_exists?(:repository_checks, :passed)
      remove_column :repository_checks, :passed
    end

    return unless column_exists?(:repository_checks, :aasm_state)

    rename_column :repository_checks, :aasm_state, :state
  end
end
