defmodule Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel do
  @moduledoc """
  Represents an instrument in the catalog, projected from events that catalog, edit, and archive instruments.
  """

  use TypedEctoSchema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "catalog"

  typed_schema "instrument" do
    field :title, :string
    field :slug, :string
    field :description, :string

    timestamps()
  end

  @doc """
  Validates and prepares the instrument read model for insertion.
  """
  def insert_changeset(attrs) when is_map(attrs) do
    insert_changeset(%__MODULE__{}, attrs)
  end

  def insert_changeset(read_model, attrs) do
    read_model
    |> cast(attrs, [:id, :title, :slug, :description])
    |> validate_required([:id, :title, :slug])
    |> unique_constraint(:slug, prefix: "catalog")
  end

  @doc """
  Validates and prepares the instrument read model for update.
  """
  def update_changeset(read_model, attrs) do
    read_model
    |> cast(attrs, [:title, :slug, :description])
    |> validate_required([:title, :slug])
    |> unique_constraint(:slug, prefix: "catalog")
  end
end
