defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged do
  @moduledoc """
  A position was cataloged: it now exists in the position catalog with its
  title, its canonical slug, an optional description and at most one optional
  reference to a piece of equipment (apparatus or instrument).
  """
  use TypedStruct
  use ExConstructor
  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :apparatusId, String.t()
    field :description, String.t()
    field :instrumentId, String.t()
  end
end
