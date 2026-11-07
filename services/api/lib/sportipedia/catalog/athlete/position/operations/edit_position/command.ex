defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPosition do
  @moduledoc """
  Edits an existing position in the catalog.

  Carries any combination of title, slug, description and equipment reference;
  the fields the patch does not carry are left alone on the aggregate.
  """

  alias Sportipedia.Catalog.Athlete.Position.Validators.InstrumentExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.ApparatusExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug

  use TypedStruct
  use ExConstructor
  use Vex.Struct

  typedstruct do
    field :id, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
    field :slug, String.t()
    field :title, String.t()
  end

  validates :id, presence: true, by: [function: &PositionExists.validate/2]

  validates :apparatusId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &ApparatusExists.validate/2, allow_nil: true]

  validates :instrumentId,
    by: [function: &AtMostOneEquipment.validate/2],
    by: [function: &InstrumentExists.validate/2, allow_nil: true]

  validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]
end
