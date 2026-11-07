defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionArchived do
  @moduledoc """
  A position was removed from the catalog.

  The event name is historical: it records that the position left the
  catalog. The fact keeps only the id — the catalog entry is gone, while
  this event stays in the event store.
  """
  use TypedStruct
  use ExConstructor
  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
  end
end
