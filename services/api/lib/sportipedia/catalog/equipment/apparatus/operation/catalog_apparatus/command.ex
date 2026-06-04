defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus do
  use TypedStruct
  use ExConstructor

  typedstruct do
    plugin TypedStructOpenApi,
      title: "equipment.CatalogApparatus",
      description: "Catalog an apparatus"

    field :id, String.t(), enforce: false
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :description, String.t(), enforce: false
  end

  use Vex.Struct

  validates :title, presence: true
  validates :slug,
    presence: true,
    by: [function: &Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug.validate/2]
end
