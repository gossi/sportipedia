defmodule Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition do
  @moduledoc """
  Catalogs a new position in the athlete catalog.
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  validates :title, presence: true
  validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]

  # One `validates` call per field: Vex keys a field's validations by the field,
  # so both rules that speak for the apparatus reference are `by:` pairs inside
  # this single call. The existence pair carries `allow_nil` because the
  # reference is optional and the check reads the value; the cross-field pair
  # carries none because it is attached to the field only as an address — its
  # body compares the two context fields and ignores the value.
  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &EquipmentExists.validate_instrument/2, allow_nil: true]

  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
  end
end
