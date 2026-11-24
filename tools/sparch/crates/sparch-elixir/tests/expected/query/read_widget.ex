defmodule Sportipedia.Catalog.Equipment.Widget.Queries.ReadWidget do
@moduledoc """
Retrieve a single widget by its id or slug
"""
@doc """
Creates a new query to fetch widgets.
"""
@spec new(String.t()) :: Ecto.Query.t()
def new(_params) do
  # TODO: construct and return the query from the read model
  raise "TODO: implement read-widget query (see the feature spec)"
end
end
