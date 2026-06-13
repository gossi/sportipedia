defmodule Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrument do
  @moduledoc """
  Edits an existing instrument in the catalog.
  """

  use TypedStruct
  use ExConstructor

  alias Sportipedia.Catalog.Equipment.Instrument.Validators.InstrumentExists
  alias Sportipedia.Catalog.Equipment.Instrument.Validators.UniqueSlug

  @doc """
  Creates a new EditInstrument command.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  # Validation
  use Vex.Struct

  validates :id, presence: true, by: [function: &InstrumentExists.validate/2]

  validates :slug,
    by: [function: &UniqueSlug.validate/2]
end
