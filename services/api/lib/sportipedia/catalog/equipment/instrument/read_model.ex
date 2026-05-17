defmodule Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel do
  use TypedEctoSchema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "catalog"

  typed_schema "instrument" do
    field :title, :string, null: false
    field :slug, :string, null: false
    field :description, :string

    timestamps()
  end

  @spec insert_changeset(map()) :: Ecto.Changeset.t()
  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:id, :title, :slug, :description])
    |> validate_required([:id, :title, :slug])
    |> unique_constraint([:slug])
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = instrument, attrs) do
    instrument
    |> cast(attrs, [:title, :slug, :description])
    |> unique_constraint(:slug,
      if: fn changeset ->
        get_change(changeset, :slug) != nil
      end
    )
  end
end
