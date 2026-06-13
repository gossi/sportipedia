defmodule Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged do
  @moduledoc """
  An apparatus was cataloged in the sport equipment catalog.
  """

  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  @doc """
  Creates a new ApparatusCataloged event.
  """
  typedstruct do
    field :id, String.t(), enforce: true
    field :title, String.t(), enforce: true
    field :slug, String.t(), enforce: true
    field :description, String.t()
  end
end
