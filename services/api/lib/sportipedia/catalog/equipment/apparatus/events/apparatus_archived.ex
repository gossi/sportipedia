defmodule Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived do
  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
  end
end
