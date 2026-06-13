defmodule Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument do
  @moduledoc """
  Catalogs a new instrument to the equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  alias Sportipedia.Catalog.Equipment.Instrument.Validators.UniqueSlug

  @doc """
  Creates a new CatalogInstrument command.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :description, String.t()
  end

  # Validation
  use Vex.Struct

  validates :title, presence: true
  validates :slug,
    presence: true,
    by: [function: &UniqueSlug.validate/2, allow_nil: true]
end
