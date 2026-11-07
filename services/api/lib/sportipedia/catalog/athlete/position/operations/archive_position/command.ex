defmodule Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition do
  @moduledoc """
  Removes the addressed position from the catalog.

  The command carries the id of the position; the position must still be in
  the catalog, so an unknown or already-removed id is rejected as not found.
  """
  use TypedStruct
  use ExConstructor
  use Vex.Struct
  alias Sportipedia.Catalog.Athlete.Position.Validators.PositionExists
  # `allow_blank` keeps the existence check off an id the caller never sent:
  # an absent address is `presence`'s to reject, and a `:not_found` for it would
  # turn the 422 the client can act on into a 404 for a resource nobody named.
  validates :id, presence: true, by: [function: &PositionExists.validate/2, allow_blank: true]

  typedstruct do
    field :id, String.t(), enforce: true
  end
end
