defmodule Sportipedia.Catalog.Equipment.Widget.WidgetAggregate do
@moduledoc """
A piece of gym apparatus a coach catalogs for later reference
"""
use TypedStruct
typedstruct do
field :id, String.t()
field :title, String.t()
field :slug, String.t()
field :archived_at, String.t()
field :coach_id, String.t()
field :description, String.t()
field :label, String.t()
field :team_id, String.t()
field :comment, String.t()
end
end
