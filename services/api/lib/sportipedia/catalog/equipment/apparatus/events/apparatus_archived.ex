defmodule Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived do
  @moduledoc """
  An apparatus was archived in the sport equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  @doc """
  Creates a new ApparatusArchived event.
  """
  typedstruct do
    field :id, String.t(), enforce: true
  end
end
