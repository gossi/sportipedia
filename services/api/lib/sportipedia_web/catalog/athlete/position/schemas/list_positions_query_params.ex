defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.ListPositionsQueryParams do
  @moduledoc """
  OpenAPI schema for documenting list-positions collection query parameters.
  """
  require OpenApiSpex
  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the list-positions collection query parameters.
  """
  OpenApiSpex.schema(%{
    title: "athlete.ListPositionsQueryParams",
    type: :object,
    properties: %{
      filter: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          title: %OpenApiSpex.Schema{
            type: :string,
            description: "Filter positions by title (partial match)"
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
          position: %OpenApiSpex.Schema{
            type: :string,
            description: "Comma-separated fields to include in the response",
            enum: ["title", "slug", "apparatusId", "description", "instrumentId"]
          }
        }
      }
    }
  })
end
