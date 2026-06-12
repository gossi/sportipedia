defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate do
  @moduledoc """
  Aggregate representing an apparatus in the sport equipment catalog.
  """

  use TypedStruct

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited

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

  @doc """
  Applies an ApparatusEdited event to the apparatus aggregate state.
  Merges non-nil event fields into the existing aggregate state.
  """
  @spec apply(%__MODULE__{}, ApparatusEdited.t()) :: %__MODULE__{}
  def apply(%__MODULE__{} = aggregate, %ApparatusEdited{} = event) do
    changes = ApparatusEdited.get_changes(event)

    aggregate
    |> Map.merge(changes)
  end

  @doc """
  Applies an ApparatusArchived event to the apparatus aggregate state.
  Returns nil to indicate the aggregate is archived.
  """
  @spec apply(%__MODULE__{}, ApparatusArchived.t()) :: nil
  def apply(%__MODULE__{} = _aggregate, %ApparatusArchived{} = _event) do
    nil
  end
end
