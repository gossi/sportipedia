defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionArchived do
  @moduledoc """
  A position was archived: it is removed from the catalog, so the fact carries
  its identity and nothing else.
  """
  use TypedStruct
  use ExConstructor
  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
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
