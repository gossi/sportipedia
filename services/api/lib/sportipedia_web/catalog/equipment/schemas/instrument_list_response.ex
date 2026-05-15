defmodule SportipediaWeb.Catalog.Equipment.Schemas.InstrumentListResponse do
  alias SportipediaWeb.Catalog.Equipment.InstrumentView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(
    OpenApiSchema.from_view(InstrumentView, title: "equipment.Instruments", many: true)
  )
end
