defmodule Sportipedia.Catalog.Equipment.Widget.Command.EditWidget do
@moduledoc """
Edits an existing widget
"""
use TypedStruct
use ExConstructor
use Vex.Struct
alias Sportipedia.Catalog.Equipment.Widget.Validators.AtMostOneOwner
alias Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug
alias Sportipedia.Catalog.Equipment.Widget.Validators.WidgetExists
# `allow_blank` keeps the existence check off an id the caller never sent:
# an absent address is `presence`'s to reject, and a `:not_found` for it would
# turn the 422 the client can act on into a 404 for a resource nobody named.
validates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true]
validates :coach_id, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]
validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]
validates :team_id, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]
typedstruct do
field :id, String.t(), enforce: true
field :coach_id, String.t()
field :description, String.t()
field :label, String.t()
field :slug, String.t()
field :team_id, String.t()
field :title, String.t()
end
end
