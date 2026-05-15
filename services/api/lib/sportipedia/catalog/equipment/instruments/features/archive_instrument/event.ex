defmodule Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentArchived do
  use ExConstructor
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
  end
end
