defmodule Sportipedia.Catalog.Equipment.Instruments.Schemas.InstrumentResponse do
  alias Sportipedia.Catalog.Equipment.Instruments.Views.InstrumentView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(OpenApiSchema.from_view(InstrumentView, title: "equipment.Instrument"))
end
