defmodule Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrumentHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument

  def handle(_aggregate, %ArchiveInstrument{} = cmd) do
    InstrumentArchived.new(cmd)
  end
end
