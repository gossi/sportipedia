defmodule Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited do
  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  def get_changes(%__MODULE__{} = event) do
    event
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
