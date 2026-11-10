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
    # The fact carries what the command supplied: the position's own raw slug and
    # at most one equipment reference. The canonical lookup path is not here —
    # the projector derives it, from the referenced equipment's current slug.
    %PositionCataloged{
      id: cmd.id,
      title: cmd.title,
      # The canonical form of a slug is lowercase, and the write side owns it:
      # with one spelling stored per slug the derived lookup path holds one
      # spelling too, which is what lets a plain unique index back the invariant.
      slug: String.downcase(cmd.slug),
      description: cmd.description,
      apparatusId: cmd.apparatusId,
      instrumentId: cmd.instrumentId
    }
  end
end
