defmodule Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument do
  @moduledoc """
  Archives an existing instrument in the catalog.
  """

  use TypedStruct
  use ExConstructor

  alias Sportipedia.Catalog.Equipment.Instrument.Validators.InstrumentExists

  @doc """
  Creates a new ArchiveInstrument command.
  """
  typedstruct do
    field :id, String.t(), enforce: true
  end

  # Validation
  use Vex.Struct

  validates :id, presence: true, by: [function: &InstrumentExists.validate/2]
end
