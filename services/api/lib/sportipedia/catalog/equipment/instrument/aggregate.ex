defmodule Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate do
  @moduledoc """
  Aggregate representing an instrument in the equipment catalog.
  """

  use TypedStruct

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged

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
end
