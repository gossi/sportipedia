defmodule Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition do
  @moduledoc """
  Catalogs a new position in the athlete catalog: a body position or stance,
  identified by its title and unique slug, with an optional description and at
  most one optional reference to a piece of equipment (apparatus or instrument).
  """

  alias Sportipedia.Catalog.Athlete.Position.Validators.InstrumentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.ApparatusExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  alias Sportipedia.Support.Validators.SlugValidator

  use TypedStruct
  use ExConstructor
  use Vex.Struct

  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
  end

  validates :title, presence: true

  validates :slug,
    presence: true,
    by: [function: &SlugValidator.validate/2],
    by: [function: &UniqueSlug.validate/2, allow_nil: true]

  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &ApparatusExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &InstrumentExists.validate/2, allow_nil: true]
end
