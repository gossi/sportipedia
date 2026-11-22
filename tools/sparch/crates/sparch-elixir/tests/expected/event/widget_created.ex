defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated do
@moduledoc """
A widget was cataloged
"""
use TypedStruct
use ExConstructor
@derive Jason.Encoder
typedstruct do
field :id, String.t(), enforce: true
field :title, String.t(), enforce: true
field :slug, String.t(), enforce: true
field :coach_id, String.t()
field :description, String.t()
field :label, String.t()
field :team_id, String.t()
end
end
