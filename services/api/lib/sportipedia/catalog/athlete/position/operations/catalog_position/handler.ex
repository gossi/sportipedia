defmodule Sportipedia.Catalog.Athlete.Position.Command.CatalogPositionHandler do
  @moduledoc """
  Handles the CatalogPosition command.
  """
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  @behaviour Commanded.Commands.Handler
  @doc """
  Handles the CatalogPosition command and returns PositionCataloged event(s).
  """
  @spec handle(PositionAggregate.t(), CatalogPosition.t()) ::
          PositionCataloged.t() | [PositionCataloged.t()]
  def handle(%PositionAggregate{} = _aggregate, %CatalogPosition{} = cmd) do
    %PositionCataloged{
      id: cmd.id,
      title: cmd.title,
      slug: String.downcase(cmd.slug),
      description: cmd.description,
      apparatusId: cmd.apparatusId,
      instrumentId: cmd.instrumentId
    }
  end
end
