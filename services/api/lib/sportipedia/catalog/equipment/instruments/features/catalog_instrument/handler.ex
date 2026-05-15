defmodule Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrumentHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instruments.Aggregate.Instrument
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrument

  def handle(%Instrument{} = _aggregate, %CatalogInstrument{} = cmd) do
    InstrumentCataloged.new(cmd)
  end
end
