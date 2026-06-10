defmodule Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged do
  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :description, String.t()
  end
end
