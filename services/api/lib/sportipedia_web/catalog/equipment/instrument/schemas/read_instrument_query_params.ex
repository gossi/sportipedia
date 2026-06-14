defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ReadInstrumentQueryParams do
  @moduledoc """
  OpenAPI schema for documenting read-instrument query parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the read-instrument query parameters.
  """
  OpenApiSpex.schema(%{
    title: "equipment.ReadInstrumentQueryParams",
    type: :object,
    properties: %{
      filter: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          slug: %OpenApiSpex.Schema{
            type: :string,
            description: "Filter instruments by slug (exact match)"
          }
        }
      },
      fields: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          instrument: %OpenApiSpex.Schema{
            type: :string,
            description: "Comma-separated fields to include in the response",
            enum: [:title, :slug, :description]
          }
        }
      }
    }
  })
end
