defmodule Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited do
  @moduledoc """
  An apparatus was edited in the sport equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  @doc """
  Creates a new ApparatusEdited event.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  @doc """
  Returns a map of only the non-nil changed fields (excluding id).
  """
  @spec get_changes(t()) :: map()
  def get_changes(%__MODULE__{} = event) do
    event
    |> Map.from_struct()
    |> Map.drop([:id])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
