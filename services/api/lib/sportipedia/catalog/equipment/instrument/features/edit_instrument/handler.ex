defmodule Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrumentHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrument

  def handle(_aggregate, %EditInstrument{} = cmd) do
    InstrumentEdited.new(cmd)
  end
end
