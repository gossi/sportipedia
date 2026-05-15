defmodule Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrumentHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrument

  def handle(_aggregate, %ArchiveInstrument{} = cmd) do
    InstrumentArchived.new(cmd)
  end
end
