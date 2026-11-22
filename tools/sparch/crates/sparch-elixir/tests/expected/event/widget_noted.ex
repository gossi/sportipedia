defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetNoted do
@moduledoc """
A note was taken of a widget, recorded for the record and nothing else
"""
use TypedStruct
use ExConstructor
@derive Jason.Encoder
typedstruct do
field :id, String.t(), enforce: true
field :comment, String.t(), enforce: true
end
end
