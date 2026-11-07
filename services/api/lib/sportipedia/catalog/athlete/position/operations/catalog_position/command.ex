defmodule Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition do
  @moduledoc """
  Catalogs a new position in the athlete catalog: a body position or stance,
  identified by its title and unique slug, with an optional description and at
  most one optional reference to a piece of equipment (apparatus or instrument).
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  validates :title, presence: true
  validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]

  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &EquipmentExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &AtMostOneEquipment.validate/2],
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
