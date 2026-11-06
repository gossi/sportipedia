defmodule Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition do
  @moduledoc """
  Archives an existing position in the athlete catalog, removing it from the
  catalog.
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  # `allow_blank` keeps the existence check off an id the caller never sent: an
  # absent address is `presence`'s to reject, and a `:not_found` for it would
  # turn the 422 the client can act on into a 404 for a resource nobody named.
  validates :id,
    presence: true,
    by: [function: &PositionExists.validate/2, allow_blank: true]

  typedstruct do
    field :id, String.t(), enforce: true
  end
end
