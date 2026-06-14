defmodule Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrumentHandler do
  @moduledoc """
  Handles the ArchiveInstrument command.
  """

  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate

  @doc """
  Handles the ArchiveInstrument command and returns an InstrumentArchived event.
  """
  @spec handle(InstrumentAggregate.t(), ArchiveInstrument.t()) :: InstrumentArchived.t()
  def handle(%InstrumentAggregate{} = _aggregate, %ArchiveInstrument{} = cmd) do
    %InstrumentArchived{
      id: cmd.id
    }
  end
end
