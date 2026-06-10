defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited

  def handle(%ApparatusAggregate{id: nil}, %EditApparatus{}) do
    {:error, :apparatus_not_found}
  end

  def handle(%ApparatusAggregate{} = _aggregate, %EditApparatus{} = cmd) do
    %ApparatusEdited{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description
    }
  end
end
