defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector do
  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.apparatus_projection",
    schema_prefix: "catalog",
    consistency: :strong

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  project %ApparatusCataloged{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :apparatus,
      ApparatusReadModel.changeset(%ApparatusReadModel{}, %{
        id: event.id,
        title: event.title,
        slug: event.slug,
        description: event.description
      })
    )
  end

  project %ApparatusEdited{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.run(:find_apparatus, fn repo, _ ->
      case repo.get(ApparatusReadModel, event.id) do
        nil -> {:error, :not_found}
        record -> {:ok, record}
      end
    end)
    |> Ecto.Multi.run(:update_apparatus, fn repo, %{find_apparatus: record} ->
      changes =
        %{}
        |> then(fn m -> if event.title, do: Map.put(m, :title, event.title), else: m end)
        |> then(fn m -> if event.slug, do: Map.put(m, :slug, event.slug), else: m end)
        |> then(fn m -> if event.description, do: Map.put(m, :description, event.description), else: m end)

      record
      |> ApparatusReadModel.update_changeset(changes)
      |> repo.update()
    end)
  end
end
