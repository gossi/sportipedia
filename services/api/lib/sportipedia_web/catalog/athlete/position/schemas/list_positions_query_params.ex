defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.ListPositionsQueryParams do
  @moduledoc """
  OpenAPI schema for documenting list-positions collection query parameters.
  """
  alias Sportipedia.Support.JSONAPI.OpenApiSchema
  alias SportipediaWeb.Catalog.Athlete.Position.PositionView

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the list-positions collection query parameters.
  """
  OpenApiSpex.schema(
    OpenApiSchema.query_params(PositionView,
      title: "athlete.ListPositionsQueryParams",
      filter: [title: "Filter positions by title (partial match)"],
      sort: ~w(title slug),
      page: :numbered
    )
  )
end
