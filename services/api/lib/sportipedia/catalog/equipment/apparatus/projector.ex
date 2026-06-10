defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector do
  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.apparatus_projection",
    schema_prefix: "catalog",
    consistency: :strong

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal

  project %ApparatusCataloged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(
      :apparatus_cataloged,
      ApparatusReadModel.insert_changeset(%ApparatusReadModel{}, Map.from_struct(event))
    )
  end

  project %ApparatusEdited{} = event, _metadata, fn multi ->
    case ApparatusInternal.apparatus_by_id(event.id) do
      nil ->
        multi

      %ApparatusReadModel{} = apparatus ->
        attrs = ApparatusEdited.get_changes(event)

        multi
        |> Ecto.Multi.update(
          :apparatus_edited,
          ApparatusReadModel.update_changeset(apparatus, attrs)
        )
    end
  end

  project %ApparatusArchived{} = event, _metadata, fn multi ->
    case ApparatusInternal.apparatus_by_id(event.id) do
      nil ->
        multi

      %ApparatusReadModel{} = apparatus ->
        multi
        |> Ecto.Multi.delete(:apparatus_archived, apparatus)
    end
  end
end
