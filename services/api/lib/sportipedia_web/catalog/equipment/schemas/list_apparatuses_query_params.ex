defmodule SportipediaWeb.Catalog.Equipment.Schemas.ListApparatusesQueryParams do
  @moduledoc """
  OpenAPI schema for documenting list-apparatuses collection query parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the list-apparatuses collection query parameters.
  """
  OpenApiSpex.schema(%{
    title: "equipment.ListApparatusesQueryParams",
    type: :object,
    properties: %{
      filter: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          title: %OpenApiSpex.Schema{
            type: :string,
            description: "Filter apparatus by title (partial match)"
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
          apparatus: %OpenApiSpex.Schema{
            type: :string,
            description: "Comma-separated fields to include in the response",
            enum: ["title", "slug", "description"]
          }
        }
      }
    }
  })
end
