defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatusHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived

  def handle(_aggregate, %Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus{} = cmd) do
    %ApparatusArchived{id: cmd.id}
  end
end
