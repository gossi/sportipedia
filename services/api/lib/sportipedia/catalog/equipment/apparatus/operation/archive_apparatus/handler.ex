defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatusHandler do
  @moduledoc """
  Handles the ArchiveApparatus command.
  """

  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived

  @doc """
  Handles the ArchiveApparatus command and returns an ApparatusArchived event.
  """
  @spec handle(ApparatusAggregate.t(), ArchiveApparatus.t()) :: ApparatusArchived.t()
  def handle(%ApparatusAggregate{} = _aggregate, %ArchiveApparatus{} = cmd) do
    %ApparatusArchived{
      id: cmd.id
    }
  end
end
