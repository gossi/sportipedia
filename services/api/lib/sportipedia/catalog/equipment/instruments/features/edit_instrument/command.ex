defmodule Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrument do
  alias Sportipedia.Catalog.Equipment.Instruments.Validators.UniqueSlug

  use TypedStruct
  use ExConstructor

  typedstruct do
    plugin TypedStructOpenApi,
      title: "equipment.EditInstrument",
      description: "The instrument to edit"

    field :id, String.t(), enforce: true
    field :title, String.t()
    field :description, String.t()
    field :slug, String.t()
  end

  # Validation
  use Vex.Struct

  validates :id, presence: true
  validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]
end
