defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged do
  @moduledoc """
  TODO: describe what happened in the domain
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
