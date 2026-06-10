defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate do
  use TypedStruct

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived

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
    %__MODULE__{
      id: aggregate.id,
      title: event.title || aggregate.title,
      slug: event.slug || aggregate.slug,
      description: event.description || aggregate.description
    }
  end

  def apply(%__MODULE__{}, %ApparatusArchived{}) do
    nil
  end
end
