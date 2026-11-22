defmodule Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets do
@moduledoc """
List all widgets with filtering, sorting, and pagination
"""
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
alias Sportipedia.Support.JSONAPI.QueryBuilder
@doc """
Creates a new query to fetch widgets.
"""
@spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
def new(query) do
  QueryBuilder.build(query, WidgetReadModel)
end
end
