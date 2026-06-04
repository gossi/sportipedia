defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate do
  use TypedStruct

  typedstruct do
    field :id, String.t()
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  def apply(
        %__MODULE__{} = _aggregate,
        %Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged{} = event
      ) do
    %__MODULE__{
      id: event.id,
      title: event.title,
      slug: event.slug,
      description: event.description
    }
  end
end
