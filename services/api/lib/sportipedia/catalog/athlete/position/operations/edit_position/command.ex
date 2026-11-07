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
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  # `allow_blank` keeps the existence check off an id the caller never sent: an
  # absent address is `presence`'s to reject, and a `:not_found` for it would
  # turn the 422 the client can act on into a 404 for a resource nobody named.
  validates :id,
    presence: true,
    by: [function: &PositionExists.validate/2, allow_blank: true]

  validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]

  # The equipment rules are the catalog command's, stated on the same fields in
  # the same order: the model's `equipment-exists` is one rule, so it has one
  # validator (`EquipmentExists`), and `at-most-one-equipment` speaks on the
  # field the model names first. An existence pair carries `allow_nil` because
  # the reference is optional and the check reads the value; the cross-field
  # pair carries none because it is attached to the field only as an address —
  # its body compares the two context fields and ignores the value. The merged
  # state (patch over what the position holds) is the aggregate handler's to
  # judge, serialized per stream.
  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &EquipmentExists.validate_instrument/2, allow_nil: true]

  typedstruct do
    field :id, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
    field :slug, String.t()
    field :title, String.t()
  end
end
