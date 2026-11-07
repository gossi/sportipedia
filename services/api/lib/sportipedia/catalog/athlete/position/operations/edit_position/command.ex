defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPosition do
  @moduledoc """
  Edits an existing position in the catalog.

  Carries any combination of title, slug, description and equipment reference;
  the fields the patch does not carry are left alone on the aggregate.
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  # `allow_blank` keeps the existence check off an id the caller never sent:
  # an absent address is `presence`'s to reject, and a `:not_found` for it would
  # turn the 422 the client can act on into a 404 for a resource nobody named.
  validates :id, presence: true, by: [function: &PositionExists.validate/2, allow_blank: true]

  # `AtMostOneEquipment` is a cross-field rule: it ignores the value it is
  # addressed by and compares the context, so its pair carries no skip option.
  # The `EquipmentExists` pair keeps its skip option: a reference the patch does
  # not carry claims nothing, and the position keeps the equipment it had.
  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate_instrument/2, allow_nil: true]

  validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]

  typedstruct do
    field :id, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
    field :slug, String.t()
    field :title, String.t()
  end
end
