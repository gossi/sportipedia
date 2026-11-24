defmodule SportipediaWeb.Catalog.Equipment.Widget.WidgetView do
@moduledoc """
Renders widget resources in JSON:API format.
"""
use JSONAPI.View, type: "widget"
def path, do: "catalog/equipment/widgets"
def fields, do: [:title, :slug, :archived_at, :coach_id, :description, :label, :team_id]
end
