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

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :title, :slug, :description])
    |> validate_required([:id, :title, :slug])
    |> unique_constraint(:slug, name: "apparatus_slug_index")
  end

  def update_changeset(struct, params) do
    struct
    |> cast(params, [:title, :slug, :description])
    |> unique_constraint(:slug, name: "apparatus_slug_index")
  end
end
