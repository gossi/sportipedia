defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionResponse do
  @moduledoc """
  OpenAPI schema for documenting position endpoints.
  """
  alias Sportipedia.Support.JSONAPI.OpenApiSchema
  alias SportipediaWeb.Catalog.Athlete.Position.PositionView
  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the position response.
  """
  OpenApiSpex.schema(OpenApiSchema.from_view(PositionView, title: "athlete.Position"))
end
