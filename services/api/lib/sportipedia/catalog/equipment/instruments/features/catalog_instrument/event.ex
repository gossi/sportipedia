defmodule Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentCataloged do
  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :description, String.t()
    field :slug, String.t(), enforce: true
  end
end
