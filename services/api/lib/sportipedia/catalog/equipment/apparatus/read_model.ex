defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel do
  use TypedEctoSchema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "catalog"

  typed_schema "apparatus" do
    field :title, :string
    field :slug, :string
    field :description, :string

    timestamps()
  end

  def catalog_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:id, :title, :slug, :description])
    |> validate_required([:id, :title, :slug])
    |> unique_constraint(:slug)
  end
end
