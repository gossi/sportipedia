defmodule Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument do
  alias Sportipedia.Catalog.Equipment.Instrument.Validators.UniqueSlug

  use TypedStruct
  use ExConstructor

  typedstruct do
    plugin TypedStructOpenApi,
      title: "equipment.CatalogInstrument",
      description: "a new instrument"

    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :description, String.t()
    field :slug, String.t(), enforce: true
  end

  # Validation
  use Vex.Struct

  validates :title, presence: true
  validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]
end
