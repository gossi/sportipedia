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
    field :lookup_slug, :string
    field :apparatusId, :binary_id
    field :description, :string
    field :instrumentId, :binary_id
    timestamps()
  end

  @doc """
  Validates and prepares the position read model for insertion.
  """
  def insert_changeset(read_model, attrs) do
    read_model
    |> cast(attrs, [:id, :title, :slug, :lookup_slug, :apparatusId, :description, :instrumentId])
    |> validate_required([:id, :title, :slug, :lookup_slug])
    |> unique_constraint(:lookup_slug)
  end

  @doc """
  Validates and prepares the position read model for update.
  """
  def update_changeset(read_model, attrs) do
    read_model
    |> cast(attrs, [:title, :slug, :lookup_slug, :apparatusId, :description, :instrumentId])
    |> unique_constraint(:lookup_slug)
  end
end
