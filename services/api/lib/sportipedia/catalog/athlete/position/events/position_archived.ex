defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionArchived do
  @moduledoc """
  A position has been archived to state it is no longer used
  """
  use TypedStruct
  use ExConstructor
  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
  end
end
