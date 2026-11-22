defmodule Sportipedia.Catalog.Equipment.Widget.WidgetReadModel do
@moduledoc """
A cataloged widget, projected from the widget aggregate
"""
use TypedEctoSchema
import Ecto.Changeset
@primary_key {:id, :binary_id, autogenerate: false}
@timestamps_opts [type: :utc_datetime_usec]
@schema_prefix "catalog"
typed_schema "widget" do
field :title, :string

field :slug, :string
field :archived_at, :utc_datetime_usec
field :coach_id, :binary_id
field :description, :string
field :label, :string
field :team_id, :binary_id
  timestamps()
end
@doc """
Validates and prepares the widget read model for insertion.
"""
def insert_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:id, :title, :slug, :archived_at, :coach_id, :description, :label, :team_id])
      |> validate_required([:id, :title, :slug])    |> unique_constraint(:slug, name: :widget_slug_index)
end
@doc """
Validates and prepares the widget read model for update.
"""
def update_changeset(read_model, attrs) do
  read_model
  |> cast(attrs, [:title, :slug, :archived_at, :coach_id, :description, :label, :team_id])
      |> unique_constraint(:slug, name: :widget_slug_index)
end
end
