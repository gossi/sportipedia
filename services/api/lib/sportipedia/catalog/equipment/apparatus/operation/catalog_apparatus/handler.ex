defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatusHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged

  def handle(%ApparatusAggregate{}, %CatalogApparatus{} = cmd) do
    %ApparatusCataloged{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description
    }
  end
end
