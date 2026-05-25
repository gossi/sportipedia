defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector do
  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.apparatus_projection",
    schema_prefix: "catalog",
    consistency: :strong

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  project %ApparatusCataloged{} = event, _metadata, fn multi ->
    changeset =
      ApparatusReadModel.catalog_changeset(%{
        id: event.id,
        title: event.title,
        slug: event.slug,
        description: event.description
      })

    Ecto.Multi.insert(multi, :insert, changeset)
  end
end
