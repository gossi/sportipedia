defmodule Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentArchived do
  @moduledoc """
  An instrument was archived in the equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  @doc """
  Creates a new InstrumentArchived event.
  """
  typedstruct do
    field :id, String.t(), enforce: true
  end
end
