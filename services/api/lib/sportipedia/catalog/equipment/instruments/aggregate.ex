defmodule Sportipedia.Catalog.Equipment.Instruments.InstrumentAggregate do
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentAggregate

  use TypedStruct

  typedstruct do
    field :id, String.t()
    field :title, String.t()
    field :description, String.t()
    field :slug, String.t()
  end

  def apply(%InstrumentAggregate{} = aggregate, %InstrumentCataloged{} = event) do
    %InstrumentCataloged{id: id, title: title, description: description, slug: slug} = event

    %InstrumentAggregate{id: id, title: title, description: description, slug: slug}
  end

  def apply(%InstrumentAggregate{} = aggregate, %InstrumentEdited{} = event) do
    changes = InstrumentEdited.get_changes(event)

    Map.merge(aggregate, changes)
  end

  def apply(%InstrumentAggregate{}, %InstrumentArchived{}) do
    nil
  end
end
