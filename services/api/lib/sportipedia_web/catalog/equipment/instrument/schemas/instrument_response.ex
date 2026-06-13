defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.InstrumentResponse do
  @moduledoc """
  OpenAPI schema for documenting instrument endpoints.
  """

  alias SportipediaWeb.Catalog.Equipment.Instrument.InstrumentView
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the instrument response.
  """
  OpenApiSpex.schema(OpenApiSchema.from_view(InstrumentView, title: "equipment.Instrument"))
end
