defmodule Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget do
@moduledoc """
Catalogs a new widget in the equipment catalog
"""
use TypedStruct
use ExConstructor
use Vex.Struct
alias Sportipedia.Catalog.Equipment.Widget.Validators.AtMostOneOwner
alias Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug
validates :title, presence: true
validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]
validates :coach_id, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]
validates :team_id, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]
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
