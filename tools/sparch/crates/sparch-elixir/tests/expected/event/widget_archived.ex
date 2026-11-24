defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetArchived do
@moduledoc """
A widget was archived
"""
use TypedStruct
use ExConstructor
@derive Jason.Encoder
typedstruct do
field :id, String.t(), enforce: true
field :archived_at, String.t()
end
end
