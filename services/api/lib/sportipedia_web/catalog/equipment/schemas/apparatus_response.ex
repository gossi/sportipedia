defmodule SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse do
  @moduledoc """
  OpenAPI schema for documenting apparatus endpoints.
  """

  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the apparatus response.
  """
  OpenApiSpex.schema(OpenApiSchema.from_view(ApparatusView, title: "equipment.Apparatus"))
end
