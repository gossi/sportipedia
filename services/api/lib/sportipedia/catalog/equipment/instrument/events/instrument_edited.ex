defmodule Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited do
  @moduledoc """
  An instrument was edited in the catalog.
  """

  use TypedStruct
  use ExConstructor

  @doc """
  Creates a new InstrumentEdited event.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  @doc """
  Returns a map of only the non-nil changed fields.
  """
  @spec get_changes(t()) :: map()
  def get_changes(%__MODULE__{} = event) do
    event
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end

defimpl Jason.Encoder, for: Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited do
  def encode(%{__struct__: _} = event, opts) do
    event
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Jason.Encode.map(opts)
  end
end
