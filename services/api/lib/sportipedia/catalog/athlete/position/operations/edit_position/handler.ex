defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler do
  @moduledoc """
  Handles the EditPosition command.

  An edit is a patch: a field the command does not carry keeps the value the
  aggregate holds — and a field carried as `nil` is not carried, because a JSON
  `null` and an absent attribute say the same thing to this handler. The event
  carries `id` plus only the changed fields. The slug travels in its canonical
  form: it is stored lowercase, so the value is normalized before the fact is
  emitted, the same way `catalog-position` stores it.

  `at-most-one-equipment` is decided here, on the effective state — the patch
  merged over what the aggregate holds. The spec states it as an invariant the
  *position aggregate* enforces, and execution of one aggregate's commands is
  serialized, so two concurrent patches cannot both fill the free slot; a
  command validator would judge the patch against a projection that may lag.
  The failure travels as `{:error, {:validation_failure, …}}` — the same shape
  `Validate` middleware responds with — so it keeps the 422 and its field
  pointer without a port-side shim, and the `ErrorClassifier` sees one vocabulary.
  """
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  @behaviour Commanded.Commands.Handler

  @doc """
  Handles the EditPosition command and returns the PositionEdited event,
  or an error when the merged state would break an invariant.
  """
  @spec handle(PositionAggregate.t(), EditPosition.t()) ::
          PositionEdited.t() | {:error, {:validation_failure, map()}}
  def handle(%PositionAggregate{} = aggregate, %EditPosition{} = cmd) do
    changes = changed_fields(cmd)

    if carries_both_references?(aggregate, changes) do
      {:error, {:validation_failure, %{apparatusId: [:at_most_one_equipment]}}}
    else
      struct!(%PositionEdited{id: cmd.id}, changes)
    end
  end

  # A reference the patch carries replaces the stored one; a field the patch
  # does not carry keeps the value the aggregate holds. One reference may never
  # end up beside the other kind — that is the `at-most-one-equipment`
  # invariant, judged on this effective state, inside the serialized stream.
  defp carries_both_references?(%PositionAggregate{} = aggregate, changes) do
    effective(changes, aggregate, :apparatusId) && effective(changes, aggregate, :instrumentId)
  end

  defp effective(changes, aggregate, field) do
    case Map.fetch(changes, field) do
      {:ok, value} -> value
      :error -> Map.get(aggregate, field)
    end
  end

  defp changed_fields(%EditPosition{} = cmd) do
    cmd
    |> Map.from_struct()
    |> Map.drop([:id])
    |> Enum.reject(fn {_field, value} -> is_nil(value) end)
    |> Map.new()
    |> normalize_slug()
  end

  defp normalize_slug(changes) do
    case Map.fetch(changes, :slug) do
      {:ok, slug} -> Map.put(changes, :slug, String.downcase(slug))
      :error -> changes
    end
  end
end
