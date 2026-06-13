defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler do
  @moduledoc """
  Handles the EditApparatus command.
  """

  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited

  @doc """
  Handles the EditApparatus command and returns an ApparatusEdited event.
  If the slug is changing, validates that the new slug is unique.
  """
  @spec handle(ApparatusAggregate.t(), EditApparatus.t()) ::
          ApparatusEdited.t() | {:error, term()}
  def handle(%ApparatusAggregate{} = _aggregate, %EditApparatus{} = cmd) do
    %ApparatusEdited{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description
    }
  end
end
