# frozen_string_literal: true

class CreateRepositoryChecks < ActiveRecord::Migration[7.2]
  def change
    create_table :repository_checks do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :commit_id
      t.string :state, null: false, default: 'queued'
      t.text :stdout
      t.integer :exit_status
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
    add_index :repository_checks, %i[repository_id created_at]
  end
end
