defmodule Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition do
  @moduledoc """
  TODO: describe what the command does to the aggregate
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  validates :id, presence: true, by: [function: &PositionExists.validate/2]

  typedstruct do
    field :id, String.t(), enforce: true
  end
end
