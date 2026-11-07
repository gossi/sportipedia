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
      slug: downcase_slug(cmd.slug),
      description: cmd.description,
      apparatusId: cmd.apparatusId,
      instrumentId: cmd.instrumentId
    }
  end

  # The canonical form of a slug is lowercase and the write side holds it:
  # the fact carries the value already lowered, so the read model stores one
  # spelling and the plain unique index can back uniqueness. A slug the patch
  # does not carry stays absent — the event's change set never holds nil for it.
  defp downcase_slug(nil), do: nil
  defp downcase_slug(slug), do: String.downcase(slug)
end
