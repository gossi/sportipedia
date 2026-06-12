defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus do
  @moduledoc """
  Archives an apparatus from the sport equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  @doc """
  Creates a new ArchiveApparatus command.
  """
  typedstruct do
    field :id, String.t(), enforce: true
  end

  use Vex.Struct

  validates :id, presence: true
end
