defmodule Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition do
  @moduledoc """
  Archives a position from the catalog.

  The command carries the id of the position; the position must still be in
  the catalog, so an unknown or already-removed id is rejected as not found.
  """

  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists

  use TypedStruct
  use ExConstructor
  use Vex.Struct

  typedstruct do
    field :id, String.t(), enforce: true
  end

  validates :id, presence: true, by: [function: &PositionExists.validate/2]
end
