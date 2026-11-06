defmodule Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition do
  @moduledoc """
  Catalogs a new position in the athlete catalog.
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.ApparatusExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.InstrumentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  validates :title, presence: true
  validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]

  validates :apparatusId, by: [function: &ApparatusExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &InstrumentExists.validate/2, allow_nil: true],
    by: [function: &AtMostOneEquipment.validate/2]

  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
  end
end
