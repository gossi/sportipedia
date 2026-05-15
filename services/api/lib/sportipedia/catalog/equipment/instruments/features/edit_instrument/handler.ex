defmodule Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrumentHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrument

  def handle(_aggregate, %EditInstrument{} = cmd) do
    InstrumentEdited.new(cmd)
  end
end
