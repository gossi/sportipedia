defmodule SportipediaWeb.Catalog.Equipment.Schemas.ApparatusListResponse do
  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(
    OpenApiSchema.from_view(ApparatusView, title: "equipment.Apparatuses", many: true)
  )
end
