defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector do
  @moduledoc """
  Projects apparatus events to the apparatus read model.
  """

  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.apparatus_projection",
    schema_prefix: "catalog",
    consistency: :strong

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged

  @doc """
  Projects an ApparatusCataloged event to the apparatus read model.
  """
  project %ApparatusCataloged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(
      :apparatus_cataloged,
      ApparatusReadModel.insert_changeset(%ApparatusReadModel{}, Map.from_struct(event))
    )
  end
end
