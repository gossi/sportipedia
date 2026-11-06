defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPosition do
  @moduledoc """
  Edits an existing position in the athlete catalog. Every field but `id` is
  optional: a field that is not supplied keeps its stored value, and a field
  supplied as `null` is not supplied — the handler reads both as "nothing to
  change", so an edit never clears a value.
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.ApparatusExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.InstrumentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  # `allow_blank` keeps the existence check off an id the caller never sent: an
  # absent address is `presence`'s to reject, and a `:not_found` for it would
  # turn the 422 the client can act on into a 404 for a resource nobody named.
  validates :id,
    presence: true,
    by: [function: &PositionExists.validate/2, allow_blank: true]

  validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]

  validates :apparatusId, by: [function: &ApparatusExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &InstrumentExists.validate/2, allow_nil: true],
    by: [function: &AtMostOneEquipment.validate/2]

  typedstruct do
    field :id, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
    field :slug, String.t()
    field :title, String.t()
  end
end
