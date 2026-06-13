defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ListInstrumentsQueryParams do
  @moduledoc """
  OpenAPI schema for documenting list-instruments collection query parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the list-instruments collection query parameters.
  """
  OpenApiSpex.schema(%{
    title: "equipment.ListInstrumentsQueryParams",
    type: :object,
    properties: %{
      filter: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          title: %OpenApiSpex.Schema{
            type: :string,
            description: "Filter instruments by title (case-insensitive partial match)"
          }
        }
      },
      sort: %OpenApiSpex.Schema{
        type: :string,
        description: "Comma-separated fields to sort by. Prefix with `-` for descending.",
        enum: ["title", "-title"]
      },
      page: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          number: %OpenApiSpex.Schema{type: :integer, default: 1},
          size: %OpenApiSpex.Schema{type: :integer, default: 20}
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
