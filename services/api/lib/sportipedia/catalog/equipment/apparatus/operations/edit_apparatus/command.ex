defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus do
  @moduledoc """
  Edits an existing apparatus in the sport equipment catalog.
  All fields except id are optional, allowing partial updates.
  """
  alias Sportipedia.Catalog.Equipment.Apparatus.Validators.ApparatusExists
  alias Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug

  use TypedStruct
  use ExConstructor

  @doc """
  Creates a new EditApparatus command.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  use Vex.Struct

  validates :id, presence: true, by: [function: &ApparatusExists.validate/2]
  validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]
end
