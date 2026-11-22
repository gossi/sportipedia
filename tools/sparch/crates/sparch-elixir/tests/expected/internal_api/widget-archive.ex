defmodule Sportipedia.Catalog.Equipment.Widget.WidgetInternal do
@moduledoc """
Internal API for querying widget read models within the bounded context.
"""
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
alias Sportipedia.Catalog.Repo
@doc """
Fetches a widget by its ID. Returns nil if not found.
"""
@spec widget_by_id(String.t()) :: WidgetReadModel.t() | nil
def widget_by_id(id) do
  Repo.get(WidgetReadModel, id)
end
end
