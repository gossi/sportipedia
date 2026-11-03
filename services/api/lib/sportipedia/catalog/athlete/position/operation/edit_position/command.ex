defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPosition do
  @moduledoc """
  TODO: describe what the command does to the aggregate
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  alias Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug
  validates :id, presence: true, by: [function: &PositionExists.validate/2]
  validates :apparatusId, by: [function: &AtMostOneEquipment.validate/2]
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
