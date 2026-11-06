defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.ListPositionsQueryParams do
  @moduledoc """
  OpenAPI schema for documenting list-positions collection query parameters.
  """
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
        description: """
        Comma-separated fields to sort by, each prefixed with `-` for a \
        descending order. Only `id`, `title` and `slug` can be sorted on: a \
        field this read does not publish is refused, not ignored.
        """,
        enum: [
          "id",
          "-id",
          "title",
          "-title",
          "slug",
          "-slug"
        ]
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
            description: "Comma-separated attributes to include in the response",
            # The parse path underscores every requested name before matching it
            # against the view's fields, so only these single-word attribute names
            # can be selected; a multi-word name (`apparatusId`) can never match
            # and the request is refused.
            enum: ["title", "slug", "description"]
          }
        }
      }
    }
  })
end
