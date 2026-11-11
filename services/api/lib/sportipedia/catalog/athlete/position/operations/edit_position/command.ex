defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPosition do
  @moduledoc """
  Edit properties of the position
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlugByEquipment
  alias Sportipedia.Support.Validators.SlugValidator
  # `allow_blank` keeps the existence check off an id the caller never sent:
  # an absent address is `presence`'s to reject, and a `:not_found` for it would
  # turn the 422 the client can act on into a 404 for a resource nobody named.
  validates :id, presence: true, by: [function: &PositionExists.validate/2, allow_blank: true]

  # `at-most-one-equipment` is a cross-field rule: it compares both references, so
  # its pair takes no skip option — skipping the pair on the field that is absent
  # would silence the rule exactly when the other field carries the second
  # reference. `equipment-exists` does read its value, so its pair skips an absent
  # reference; the namespace-move check reads the reference the same way — an
  # absent one moves nothing — so it skips with `allow_nil` too, and the patch's
  # effective namespace makes the stored slug's new home before dispatch.
  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true],
    by: [function: &UniqueSlugByEquipment.validate_namespace_move/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true],
    by: [function: &UniqueSlugByEquipment.validate_namespace_move/2, allow_nil: true]

  # Both slug pairs read the value, so both skip an absent one — the patch may
  # carry neither. `SlugValidator` keeps the raw slug inside the canonical
  # charset, which is what makes the namespaces of `unique-slug-by-equipment`
  # disjoint by construction: a raw slug can never carry the `/` that only the
  # namespaced form may have.
  validates :slug,
    by: [function: &SlugValidator.validate/2, allow_nil: true],
    by: [function: &UniqueSlugByEquipment.validate/2, allow_nil: true]

  typedstruct do
    field :id, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
    field :slug, String.t()
    field :title, String.t()
  end
end
