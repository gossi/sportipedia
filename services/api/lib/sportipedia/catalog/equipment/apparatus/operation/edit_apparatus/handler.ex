defmodule Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler do
  @moduledoc """
  Handles the EditApparatus command.
  """

  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited

  @doc """
  Handles the EditApparatus command and returns an ApparatusEdited event.
  If the slug is changing, validates that the new slug is unique.
  """
  @spec handle(ApparatusAggregate.t(), EditApparatus.t()) ::
          ApparatusEdited.t() | {:error, term()}
  def handle(%ApparatusAggregate{} = aggregate, %EditApparatus{} = cmd) do
    with :ok <- check_slug_uniqueness(aggregate, cmd) do
      %ApparatusEdited{
        id: cmd.id,
        title: cmd.title,
        slug: cmd.slug,
        description: cmd.description
      }
    end
  end

  defp check_slug_uniqueness(%ApparatusAggregate{slug: current_slug}, %EditApparatus{slug: nil}) do
    # Slug not changing
    :ok
  end

  defp check_slug_uniqueness(%ApparatusAggregate{slug: current_slug}, %EditApparatus{slug: new_slug})
       when current_slug == new_slug do
    # Slug not changing (same value)
    :ok
  end

  defp check_slug_uniqueness(%ApparatusAggregate{}, %EditApparatus{slug: new_slug}) do
    # Slug is changing — check uniqueness
    case ApparatusInternal.apparatus_by_slug(new_slug) do
      nil -> :ok
      _ -> {:error, {:validation_failure, %{slug: ["slug already exists"]}}}
    end
  end
end
