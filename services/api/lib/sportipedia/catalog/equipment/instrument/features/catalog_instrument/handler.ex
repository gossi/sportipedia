defmodule Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrumentHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument

  def handle(_aggregate, %CatalogInstrument{} = cmd) do
    InstrumentCataloged.new(cmd)
  end
end
