defmodule Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug do
@moduledoc """
Query to fetch a widget by its slug.
"""
import Ecto.Query
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
@doc """
Creates a new query to fetch a widget by slug.
"""
@spec new(String.t()) :: Ecto.Query.t()
def new(slug) do
  from(r in WidgetReadModel,
    where: r.slug == ^slug
  )
end
end
