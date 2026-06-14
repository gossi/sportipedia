defmodule Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrumentHandler do
  @moduledoc """
  Handles the CatalogInstrument command.
  """

  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged

  @doc """
  Handles the CatalogInstrument command and returns an InstrumentCataloged event.
  """
  @spec handle(InstrumentAggregate.t(), CatalogInstrument.t()) :: InstrumentCataloged.t()
  def handle(%InstrumentAggregate{} = _aggregate, %CatalogInstrument{} = cmd) do
    %InstrumentCataloged{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description
    }
  end
end
