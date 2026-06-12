defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus do
  @moduledoc """
  Edits an existing apparatus in the sport equipment catalog.
  All fields except id are optional, allowing partial updates.
  """

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
end
