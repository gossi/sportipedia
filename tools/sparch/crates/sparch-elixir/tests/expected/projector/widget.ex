defmodule Sportipedia.Catalog.Equipment.Widget.WidgetProjector do
@moduledoc """
Projects widget events to the widget read model.
"""
  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.widget_projection",
    schema_prefix: "catalog",
    consistency: :strong
end
