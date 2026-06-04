defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatusHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged

  def handle(
        _aggregate,
        %Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus{} = cmd
      ) do
    %ApparatusCataloged{
      id: cmd.id || UUID.uuid4(),
      title: cmd.title,
      slug: String.downcase(cmd.slug),
      description: cmd.description
    }
  end
end
