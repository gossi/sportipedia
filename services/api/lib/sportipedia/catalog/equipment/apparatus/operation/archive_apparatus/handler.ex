defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatusHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived

  def handle(%ApparatusAggregate{id: nil}, %ArchiveApparatus{}) do
    {:error, :apparatus_not_found}
  end

  def handle(%ApparatusAggregate{} = _aggregate, %ArchiveApparatus{id: id}) do
    [%ApparatusArchived{id: id}]
  end
end
