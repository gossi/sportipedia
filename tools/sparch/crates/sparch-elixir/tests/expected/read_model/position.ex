defmodule Sportipedia.Catalog.Athlete.Position.PositionReadModel do
@moduledoc """
Represents a position in the athlete.
"""
use TypedEctoSchema
import Ecto.Changeset
alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
@primary_key {:id, :binary_id, autogenerate: false}
@timestamps_opts [type: :utc_datetime_usec]
@schema_prefix "catalog"
typed_schema "position" do
field :title, :string

field :raw_slug, :string
field :slug, :string
belongs_to :apparatus, ApparatusReadModel
field :description, :string
belongs_to :instrument, InstrumentReadModel, foreign_key: :installed_instrument_id
  timestamps()
end
@doc """
Validates and prepares the position read model for insertion.
"""
def insert_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:id, :title, :raw_slug, :slug, :apparatus_id, :description, :installed_instrument_id])
      |> validate_required([:id, :title, :raw_slug, :slug])
end
@doc """
Validates and prepares the position read model for update.
"""
def update_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:title, :raw_slug, :slug, :apparatus_id, :description, :installed_instrument_id])
  
end
end
