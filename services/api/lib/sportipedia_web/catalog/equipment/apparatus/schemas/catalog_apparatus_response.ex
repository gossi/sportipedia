defmodule SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse do
  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(OpenApiSchema.from_view(ApparatusView, title: "equipment.Apparatus"))
end
