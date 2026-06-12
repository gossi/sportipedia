defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate do
  @moduledoc """
  Aggregate representing an apparatus in the sport equipment catalog.
  """

  use TypedStruct

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged

  typedstruct do
    field :id, String.t()
    field :title, String.t()
    field :slug, String.t()
    field :description, String.t()
  end

  @doc """
  Applies an event to the apparatus aggregate state.
  """
  @spec apply(%__MODULE__{}, ApparatusCataloged.t()) :: %__MODULE__{}
  def apply(%__MODULE__{} = _aggregate, %ApparatusCataloged{} = event) do
    %__MODULE__{
      id: event.id,
      title: event.title,
      slug: event.slug,
      description: event.description
    }
  end
end
