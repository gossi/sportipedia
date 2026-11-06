defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionCollectionResponse do
  @moduledoc """
  OpenAPI schema for documenting position collection endpoints.
  """
  alias Sportipedia.Support.JSONAPI.OpenApiSchema
  alias SportipediaWeb.Catalog.Athlete.Position.PositionView
  require OpenApiSpex
  alias SportipediaWeb.Catalog.Athlete.Position.PositionView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the position collection response.
  """
  OpenApiSpex.schema(
    OpenApiSchema.from_view(PositionView, title: "athlete.Positions", many: true)
  )
end
