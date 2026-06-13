defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate do
  @moduledoc """
  Aggregate representing an apparatus in the sport equipment catalog.
  """

  use TypedStruct

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited

  typedstruct do
    field :id, String.t()
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  def apply(%__MODULE__{} = _aggregate, %ApparatusCataloged{} = event) do
    %__MODULE__{
      id: event.id,
      title: event.title,
      slug: event.slug,
      description: event.description
    }
  end

  def apply(%__MODULE__{} = aggregate, %ApparatusEdited{} = event) do
    changes = ApparatusEdited.get_changes(event)

    aggregate
    |> Map.merge(changes)
  end

  def apply(%__MODULE__{} = _aggregate, %ApparatusArchived{} = _event) do
    nil
  end
end
