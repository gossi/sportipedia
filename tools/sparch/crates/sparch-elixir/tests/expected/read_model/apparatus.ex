defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel do
@moduledoc """
Represents a apparatus in the equipment.
"""
use TypedEctoSchema
import Ecto.Changeset
alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
alias Sportipedia.Catalog.Equipment.ApparatusCertification.ApparatusCertificationReadModel
alias Sportipedia.Catalog.Equipment.Tag.TagReadModel
@primary_key {:id, :binary_id, autogenerate: false}
@timestamps_opts [type: :utc_datetime_usec]
@schema_prefix "catalog"
typed_schema "apparatus" do
field :title, :string

field :slug, :string
has_one :certification, ApparatusCertificationReadModel
field :description, :string
has_many :positions, PositionReadModel
many_to_many :tags, TagReadModel, join_through: "apparatuses_tags"
  timestamps()
end
@doc """
Validates and prepares the apparatus read model for insertion.
"""
def insert_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:id, :title, :slug, :description])
      |> validate_required([:id, :title, :slug])
end
@doc """
Validates and prepares the apparatus read model for update.
"""
def update_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:title, :slug, :description])
  
end
end
