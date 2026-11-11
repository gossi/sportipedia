defmodule SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.ListApparatusesQueryParams do
  @moduledoc """
  OpenAPI schema for documenting list-apparatuses collection query parameters.
  """
  alias Sportipedia.Support.JSONAPI.OpenApiSchema
  alias SportipediaWeb.Catalog.Equipment.Apparatus.ApparatusView

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the list-apparatuses collection query parameters.
  """
  OpenApiSpex.schema(
    OpenApiSchema.query_params(ApparatusView,
      title: "equipment.ListApparatusesQueryParams",
      filter: [title: "Filter apparatus by title (partial match)"],
      sort: ~w(title slug),
      page: :numbered
    )
  )
end
