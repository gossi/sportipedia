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

  The patch keeps patch shape: a field the command does not carry stays `nil` in
  the fact, so `PositionEdited.get_changes/1` leaves the stored value alone —
  an omitted equipment reference is not a cascade. The raw slug is emitted in
  its canonical (lower-cased) form, so the read model holds one spelling and
  the derived `slug` inherits it.
  """
  @spec handle(PositionAggregate.t(), EditPosition.t()) ::
          PositionEdited.t() | [PositionEdited.t()]
  def handle(%PositionAggregate{}, %EditPosition{} = cmd) do
    %PositionEdited{
      id: cmd.id,
      title: cmd.title,
      slug: canonical_slug(cmd.slug),
      description: cmd.description,
      apparatusId: cmd.apparatusId,
      instrumentId: cmd.instrumentId
    }
  end

  defp canonical_slug(slug) when is_binary(slug), do: String.downcase(slug)
  defp canonical_slug(nil), do: nil
end
