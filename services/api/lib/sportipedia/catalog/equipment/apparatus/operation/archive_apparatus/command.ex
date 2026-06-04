defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus do
  use TypedStruct
  use ExConstructor

  typedstruct do
    plugin TypedStructOpenApi,
      title: "equipment.ArchiveApparatus",
      description: "Archive (hard-delete) an apparatus"

    field :id, String.t(), enforce: true
  end

  # Validation
  use Vex.Struct
end
