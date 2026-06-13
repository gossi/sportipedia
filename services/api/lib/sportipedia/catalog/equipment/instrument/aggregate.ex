defmodule Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate do
  @moduledoc """
  Aggregate representing an instrument in the equipment catalog.
  """

  use TypedStruct

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited

  typedstruct do
    field :id, String.t()
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  def apply(%__MODULE__{} = _aggregate, %InstrumentCataloged{} = event) do
    %__MODULE__{
      id: event.id,
      title: event.title,
      slug: event.slug,
      description: event.description
    }
  end

  def apply(%__MODULE__{} = aggregate, %InstrumentEdited{} = event) do
    %__MODULE__{
      id: aggregate.id,
      title: event.title || aggregate.title,
      slug: event.slug || aggregate.slug,
      description:
        if(is_nil(event.description), do: aggregate.description, else: event.description)
    }
  end
end
