defmodule Sportipedia.Catalog.Athlete.Position.PositionProjector do
  @moduledoc """
  Projects position events to the position read model.
  """
  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "athlete.position_projection",
    schema_prefix: "catalog",
    consistency: :strong

  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.PositionInternal
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Projects an PositionCataloged event to the position read model.
  """
  project %PositionCataloged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(
      :position_cataloged,
      PositionReadModel.insert_changeset(%PositionReadModel{}, Map.from_struct(event))
    )
  end

  @doc """
  Projects an PositionArchived event to hard-delete the position read model.
  """
  project %PositionArchived{} = event, _metadata, fn multi ->
    case PositionInternal.position_by_id(event.id) do
      nil ->
        multi

      %PositionReadModel{} = position ->
        multi
        |> Ecto.Multi.delete(:position_archived, position)
    end
  end

  @doc """
  Projects an PositionEdited event to update the position read model.
  """
  project %PositionEdited{} = event, _metadata, fn multi ->
    case PositionInternal.position_by_id(event.id) do
      nil ->
        multi

      %PositionReadModel{} = position ->
        attrs = PositionEdited.get_changes(event)

        multi
        |> Ecto.Multi.update(
          :position_edited,
          PositionReadModel.update_changeset(position, attrs)
        )
    end
  end
end
