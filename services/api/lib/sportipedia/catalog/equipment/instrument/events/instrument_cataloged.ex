defmodule Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged do
  @moduledoc """
  An instrument was cataloged in the equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  @doc """
  Creates a new InstrumentCataloged event.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :description, String.t()
  end
end
