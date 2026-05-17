defmodule SportipediaWeb.Catalog.Equipment.Schemas.InstrumentResponse do
  alias SportipediaWeb.Catalog.Equipment.InstrumentView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(OpenApiSchema.from_view(InstrumentView, title: "equipment.Instrument"))
end
