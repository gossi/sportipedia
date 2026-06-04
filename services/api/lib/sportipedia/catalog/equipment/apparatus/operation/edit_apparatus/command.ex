defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus do
  use TypedStruct
  use ExConstructor

  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  use Vex.Struct

  validates :slug, by: [function: &Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug.validate/2]
end
