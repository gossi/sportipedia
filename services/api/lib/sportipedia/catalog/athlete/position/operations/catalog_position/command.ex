defmodule Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition do
  @moduledoc """
  Catalogs a new position in the catalog: a body position or stance, optionally bound to one piece of equipment
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlugByEquipment
  alias Sportipedia.Support.Validators.SlugValidator
  validates :title, presence: true

  # The slug's canonical charset is a boundary rule — `SlugValidator` rejects a
  # raw slug that could not keep `unique-slug-by-equipment`'s namespaces
  # disjoint (a raw slug carrying `/` could claim another namespace's canonical
  # path). The slug is required here, so neither pair carries a skip option.
  validates :slug,
    presence: true,
    by: [function: &SlugValidator.validate/2],
    by: [function: &UniqueSlugByEquipment.validate/2]

  # `at-most-one-equipment` is a cross-field rule: it compares both references,
  # so its pair takes no skip option — skipping the pair on the field that is
  # absent would silence the rule exactly when the other field carries the
  # second reference. `equipment-exists` does read its value, so its pair skips
  # an absent reference.
  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true]

  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
  end
end
