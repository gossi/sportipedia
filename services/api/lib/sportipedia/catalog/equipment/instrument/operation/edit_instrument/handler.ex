defmodule Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrumentHandler do
  @moduledoc """
  Handles the EditInstrument command.
  """

  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate

  @doc """
  Handles the EditInstrument command and returns an InstrumentEdited event.
  """
  @spec handle(InstrumentAggregate.t(), EditInstrument.t()) :: InstrumentEdited.t()
  def handle(%InstrumentAggregate{} = _aggregate, %EditInstrument{} = cmd) do
    %InstrumentEdited{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description
    }
  end
end
