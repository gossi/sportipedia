defmodule Sportipedia.Catalog.Exercises.Exercise.ExerciseReadModel do
@moduledoc """
Represents a exercise in the exercises.
"""
use TypedEctoSchema
import Ecto.Changeset
alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
alias Sportipedia.Catalog.Equipment.Tag.TagReadModel
alias Sportipedia.Catalog.Exercises.ExerciseTag.ExerciseTagReadModel
@primary_key {:id, :binary_id, autogenerate: false}
@timestamps_opts [type: :utc_datetime_usec]
@schema_prefix "catalog"
typed_schema "exercise" do
field :title, :string

field :difficulty, :integer
belongs_to :primary_apparatus, ApparatusReadModel
belongs_to :safety_apparatus, ApparatusReadModel, foreign_key: :backup_apparatus_id
many_to_many :tags, TagReadModel, join_through: ExerciseTagReadModel, join_keys: [exercise_id: :id, tag_id: :id]
  timestamps()
end
@doc """
Validates and prepares the exercise read model for insertion.
"""
def insert_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:id, :title, :difficulty, :primary_apparatus_id, :backup_apparatus_id])
      |> validate_required([:id, :title])
end
@doc """
Validates and prepares the exercise read model for update.
"""
def update_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:title, :difficulty, :primary_apparatus_id, :backup_apparatus_id])
  
end
end
