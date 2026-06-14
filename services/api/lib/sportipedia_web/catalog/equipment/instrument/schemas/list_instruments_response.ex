defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ListInstrumentsResponse do
  @moduledoc """
  OpenAPI schema for documenting the list-instruments collection endpoint.
  """

  alias SportipediaWeb.Catalog.Equipment.Instrument.InstrumentView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the list-instruments collection response.
  """
  OpenApiSpex.schema(
    OpenApiSchema.from_view(InstrumentView, title: "equipment.Instruments", many: true)
  )
end
