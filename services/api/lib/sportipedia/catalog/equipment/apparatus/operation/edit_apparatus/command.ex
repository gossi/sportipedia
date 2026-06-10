defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus do
  use TypedStruct
  use ExConstructor

  alias Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug

  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  use Vex.Struct

  validates :title, format: [with: ~r/.+/, allow_nil: true]

  validates :slug,
    format: [with: ~r/.+/, allow_nil: true],
    by: [function: &UniqueSlug.validate/2, allow_nil: true]
end
