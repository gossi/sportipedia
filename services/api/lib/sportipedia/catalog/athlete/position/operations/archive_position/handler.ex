defmodule Sportipedia.Catalog.Athlete.Position.Command.ArchivePositionHandler do
  @moduledoc """
  Handles the ArchivePosition command.
  """
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  @behaviour Commanded.Commands.Handler

  @doc """
  Handles the ArchivePosition command and returns the PositionArchived event.

  The event carries the id alone: archiving removes the position, so there is no
  other fact to state.
  """
  @spec handle(PositionAggregate.t(), ArchivePosition.t()) :: PositionArchived.t()
  def handle(%PositionAggregate{} = _aggregate, %ArchivePosition{} = cmd) do
    %PositionArchived{id: cmd.id}
  end
end
