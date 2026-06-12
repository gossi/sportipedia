defmodule SportipediaWeb.Catalog.Equipment.Schemas.ApparatusCollectionResponse do
  @moduledoc """
  OpenAPI schema for documenting apparatus collection endpoints.
  """

  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the apparatus collection response.
  """
  OpenApiSpex.schema(
    OpenApiSchema.from_view(ApparatusView, title: "equipment.Apparatuses", many: true)
  )
end
