defmodule Sportipedia.Catalog.Athlete.Position.PositionAggregate do
  @moduledoc """
  A body position or stance, optionally bound to a specific piece of equipment (apparatus or instrument)
  """

  use TypedStruct

  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited

  typedstruct do
    field :id, String.t()
    field :title, String.t()
    field :slug, String.t()
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
  end

  def apply(%__MODULE__{} = _aggregate, %PositionArchived{} = _event) do
    nil
  end

  def apply(%__MODULE__{} = _aggregate, %PositionCataloged{} = event) do
    %__MODULE__{
      id: event.id,
      title: event.title,
      slug: event.slug,
      apparatusId: event.apparatusId,
      description: event.description,
      instrumentId: event.instrumentId
    }
  end

  def apply(%__MODULE__{} = aggregate, %PositionEdited{} = event) do
    changes = PositionEdited.get_changes(event)

    aggregate
    |> Map.merge(changes)
  end
end
