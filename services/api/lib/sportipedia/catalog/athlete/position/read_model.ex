defmodule Sportipedia.Catalog.Athlete.Position.PositionReadModel do
  @moduledoc """
  Represents a position in the athlete.
  """
  use TypedEctoSchema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "catalog"
  typed_schema "position" do
    field :title, :string
    field :slug, :string
    # The domain model names its properties in camelCase (`apparatusId`), while
    # the storage column stays snake_case (`apparatus_id`): the `:source` option
    # is the bridge. It also lets the projector hand the event's own struct
    # fields straight to the changeset, because those are named like the model.
    field :apparatusId, :binary_id, source: :apparatus_id
    field :description, :string
    field :instrumentId, :binary_id, source: :instrument_id
    timestamps()
  end

  @doc """
  Validates and prepares the position read model for insertion.
  """
  def insert_changeset(read_model, attrs) do
    read_model
    |> cast(attrs, [:id, :title, :slug, :apparatusId, :description, :instrumentId])
    |> validate_required([:id, :title, :slug])
    |> unique_constraint(:slug, name: :position_slug_index)
  end

  @doc """
  Validates and prepares the position read model for update.
  """
  def update_changeset(read_model, attrs) do
    read_model
    |> cast(attrs, [:title, :slug, :apparatusId, :description, :instrumentId])
    |> unique_constraint(:slug, name: :position_slug_index)
  end
end
