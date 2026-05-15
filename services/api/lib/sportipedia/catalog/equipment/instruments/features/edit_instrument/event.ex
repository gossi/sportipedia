defmodule Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentEdited do
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentEdited
  use TypedStruct
  use ExConstructor

  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :description, String.t()
    field :slug, String.t()
  end

  def get_changes(%InstrumentEdited{} = event) do
    event
    |> Map.from_struct()
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defimpl Jason.Encoder do
    def encode(%InstrumentEdited{} = event, opts) do
      InstrumentEdited.get_changes(event)
      |> Jason.Encode.map(opts)
    end
  end
end
