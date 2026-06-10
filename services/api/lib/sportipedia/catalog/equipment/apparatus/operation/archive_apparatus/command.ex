defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus do
  use TypedStruct
  use ExConstructor
  use Vex.Struct

  typedstruct do
    field :id, String.t(), enforce: true
  end
end
