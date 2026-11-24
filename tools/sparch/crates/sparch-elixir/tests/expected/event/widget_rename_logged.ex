defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged do
@moduledoc """
The rename of a widget was written to the audit trail
"""
use TypedStruct
use ExConstructor
@derive Jason.Encoder
typedstruct do
field :id, String.t(), enforce: true
end
end
