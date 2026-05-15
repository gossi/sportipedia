defmodule Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrument do
  use TypedStruct
  use ExConstructor

  typedstruct do
    plugin TypedStructOpenApi,
      title: "equipment.ArchiveInstrument",
      description: "Instrument"

    field :id, String.t(), enforce: true
  end

  # Validation
  use Vex.Struct

  validates :id, presence: true
end
