defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus

  def handle(_aggregate, %EditApparatus{} = cmd) do
    %ApparatusEdited{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description
    }
  end
end
