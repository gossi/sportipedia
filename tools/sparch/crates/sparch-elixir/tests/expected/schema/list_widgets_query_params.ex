defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.ListWidgetsQueryParams do
@moduledoc """
OpenAPI schema for documenting list-widgets collection query parameters.
"""
alias Sportipedia.Support.JSONAPI.OpenApiSchema
alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView
require OpenApiSpex
@doc """
Returns the OpenAPI schema for the list-widgets collection query parameters.
"""
OpenApiSpex.schema(
  OpenApiSchema.query_params(WidgetView,
          title: "equipment.ListWidgetsQueryParams",
      filter: [title: "Filter widgets by title (partial match)"],
      sort: ~w(title slug),
      page: :numbered
  )
)
end
