defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ListInstrumentsQueryParams do
  @moduledoc """
  OpenAPI schema for documenting list-instruments collection query parameters.
  """
  alias Sportipedia.Support.JSONAPI.OpenApiSchema
  alias SportipediaWeb.Catalog.Equipment.Instrument.InstrumentView

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the list-instruments collection query parameters.
  """
  OpenApiSpex.schema(
    OpenApiSchema.query_params(InstrumentView,
      title: "equipment.ListInstrumentsQueryParams",
      filter: [
        title: "Filter instruments by title (partial match)",
        slug: "Filter instruments by slug (partial match)"
      ],
      sort: ~w(title slug),
      page: :numbered
    )
  )
end
