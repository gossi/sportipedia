defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatusHandler do
  @moduledoc """
  Handles the CatalogApparatus command.
  """

  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged

  @doc """
  Handles the CatalogApparatus command and returns an ApparatusCataloged event.
  """
  @spec handle(ApparatusAggregate.t(), CatalogApparatus.t()) :: ApparatusCataloged.t()
  def handle(%ApparatusAggregate{} = _aggregate, %CatalogApparatus{} = cmd) do
    %ApparatusCataloged{
      id: cmd.id,
      title: cmd.title,
      slug: cmd.slug,
      description: cmd.description
    }
  end
end
