defmodule Sportipedia.Catalog.Athlete.Position.Command.CatalogPositionHandler do
  @moduledoc """
  Handles the CatalogPosition command.
  """
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  @behaviour Commanded.Commands.Handler

  @doc """
  Handles the CatalogPosition command and returns the PositionCataloged event.
  """
  @spec handle(PositionAggregate.t(), CatalogPosition.t()) :: PositionCataloged.t()
  def handle(%PositionAggregate{} = _aggregate, %CatalogPosition{} = cmd) do
    %PositionCataloged{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      apparatusId: cmd.apparatusId,
      description: cmd.description,
      instrumentId: cmd.instrumentId
    }
  end
end
