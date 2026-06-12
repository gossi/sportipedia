defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus do
  @moduledoc """
  Catalogs a new apparatus in the sport equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  alias Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug

  @doc """
  Creates a new CatalogApparatus command.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :description, String.t()
  end

  use Vex.Struct

  validates :title, presence: true
  validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]
end
