defmodule Sportipedia.Catalog.Equipment.Widget.Command.RelabelWidget do
@moduledoc """
Renames a widget and records the rename for the audit trail
"""
use TypedStruct
use ExConstructor
use Vex.Struct
alias Sportipedia.Catalog.Equipment.Widget.Validators.WidgetExists
# `allow_blank` keeps the existence check off an id the caller never sent:
# an absent address is `presence`'s to reject, and a `:not_found` for it would
# turn the 422 the client can act on into a 404 for a resource nobody named.
validates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true]
validates :label, presence: true
typedstruct do
field :id, String.t(), enforce: true
field :label, String.t(), enforce: true
end
end
