defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.CatalogInstrumentRequest do
  @moduledoc """
  OpenAPI schema for documenting the catalog-instrument request parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the catalog-instrument request.
  """
  OpenApiSpex.schema(%{
    title: "equipment.CatalogInstrumentRequest",
    type: :object,
    properties: %{
      title: %OpenApiSpex.Schema{type: :string, description: "Name of the instrument"},
      slug: %OpenApiSpex.Schema{
        type: :string,
        description: "URL-friendly unique identifier"
      },
      description: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Optional description"
      }
    },
    required: [:title, :slug]
  })
end
