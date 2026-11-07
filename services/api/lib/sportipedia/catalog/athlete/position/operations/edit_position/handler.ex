defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler do
  @moduledoc """
  Handles the EditPosition command.
  """

  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate

  @behaviour Commanded.Commands.Handler

  @doc """
  Handles the EditPosition command and returns PositionEdited event(s).
  """
  @spec handle(PositionAggregate.t(), EditPosition.t()) ::
          PositionEdited.t() | [PositionEdited.t()]
  def handle(%PositionAggregate{} = _aggregate, %EditPosition{} = cmd) do
    %PositionEdited{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description,
      apparatusId: cmd.apparatusId,
      instrumentId: cmd.instrumentId
    }
  end
end
