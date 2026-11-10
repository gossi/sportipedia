defmodule Sportipedia.Catalog.Athlete.Position.PositionProjector do
  @moduledoc """
  Projects position events to the position read model.

  The read model is fed by three aggregates: the position's own facts, and the
  `apparatus-edited` / `instrument-edited` facts of the equipment a position is
  bound to, which re-derive the canonical lookup path of every bound position.
  """
  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "athlete.position_projection",
    schema_prefix: "catalog",
    consistency: :strong

  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.PositionInternal
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  # The canonical path is namespaced by the referenced equipment's current slug,
  # read through the equipment constituents' own ports (never their store).
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  # catalog-position: an equipment rename moves the namespace its bound positions
  # live in, so the position projection reads these two equipment facts too.
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited

  @doc """
  Projects an PositionCataloged event to the position read model.

  The event carries the position's raw slug and its equipment reference; the
  canonical `lookup_slug` is derived here — `<equipment-slug>/<position-slug>`
  for a bound position, the bare position slug for an unbound one.
  """
  project %PositionCataloged{} = event, _metadata, fn multi ->
    attrs =
      event
      |> Map.from_struct()
      |> Map.put(
        :lookup_slug,
        derive_lookup_slug(event.slug, event.apparatusId, event.instrumentId)
      )

    multi
    |> Ecto.Multi.insert(
      :position_cataloged,
      PositionReadModel.insert_changeset(%PositionReadModel{}, attrs)
    )
  end

  @doc """
  Projects an PositionArchived event to hard-delete the position read model.
  """
  project %PositionArchived{} = event, _metadata, fn multi ->
    case PositionInternal.position_by_id(event.id) do
      nil ->
        multi

      %PositionReadModel{} = position ->
        multi
        |> Ecto.Multi.delete(:position_archived, position)
    end
  end

  @doc """
  Projects an PositionEdited event to update the position read model.

  The fact is a patch — `PositionEdited.get_changes/1` carries the fields the edit
  supplied and drops the ones it did not — so an equipment reference the patch
  omits is left alone, not cascaded. The canonical `lookup_slug` is derived, never
  supplied: it moves when the raw slug or the binding moved, and stays where it is
  for every other patch. When the raw slug moved alone, the namespace comes from
  the stored binding.
  """
  project %PositionEdited{} = event, _metadata, fn multi ->
    case PositionInternal.position_by_id(event.id) do
      nil ->
        multi

      %PositionReadModel{} = position ->
        attrs = PositionEdited.get_changes(event)

        multi
        |> Ecto.Multi.update(
          :position_edited,
          PositionReadModel.update_changeset(position, rederive_lookup_slug(position, attrs))
        )
    end
  end

  # A key present in the patch is a field that actually changed: `get_changes/1`
  # dropped the nils. So the derived path is recomputed exactly for the patches
  # that moved one of its two inputs — the raw slug, and the equipment binding
  # taken from the patch when it carries one, from the row otherwise.
  defp rederive_lookup_slug(%PositionReadModel{} = position, attrs) do
    if Enum.any?([:slug, :apparatusId, :instrumentId], &Map.has_key?(attrs, &1)) do
      Map.put(attrs, :lookup_slug, derived_lookup_slug(position, attrs))
    else
      attrs
    end
  end

  defp derived_lookup_slug(%PositionReadModel{} = position, attrs) do
    derive_lookup_slug(
      Map.get(attrs, :slug, position.slug),
      Map.get(attrs, :apparatusId, position.apparatusId),
      Map.get(attrs, :instrumentId, position.instrumentId)
    )
  end

  @doc """
  Projects an ApparatusEdited event to re-derive the lookup slug of every
  position bound to the renamed apparatus.

  No generator call owns these two clauses: `sp.gen.projector` resolves a read
  model by the event's own aggregate, so an equipment fact reaches the equipment
  projector. The position read model is the one that names them, and they sit
  beside the derivation they share with the position clauses.
  """
  project %ApparatusEdited{} = event, _metadata, fn multi ->
    rebind_namespace(multi, :apparatus_renamed, :apparatusId, event)
  end

  @doc """
  Projects an InstrumentEdited event to re-derive the lookup slug of every
  position bound to the renamed instrument.
  """
  project %InstrumentEdited{} = event, _metadata, fn multi ->
    rebind_namespace(multi, :instrument_renamed, :instrumentId, event)
  end

  # ── catalog-position: the canonical path ─────────────────────────────────
  #
  # `lookup_slug` is the one column the read model does not get from an event:
  # it is derived, from the position's own raw slug and the *current* slug of
  # the equipment it is bound to. Both the position clauses and the equipment
  # rename clauses below read it through this helper, so the canonical form is
  # stated exactly once.
  defp derive_lookup_slug(slug, apparatus_id, instrument_id) do
    canonical_path(slug, equipment_slug(apparatus_id, instrument_id))
  end

  # An unbound position is its own slug; a bound one lives under its equipment.
  defp canonical_path(slug, nil), do: slug
  defp canonical_path(slug, equipment_slug), do: "#{equipment_slug}/#{slug}"

  # The equipment slug comes from the referenced constituent's public API —
  # a position never reaches into the equipment store. A reference that names
  # no equipment row leaves the position un-namespaced: the command's
  # `equipment-exists` rule is what keeps that unreachable through the API.
  defp equipment_slug(apparatus_id, _instrument_id) when not is_nil(apparatus_id) do
    case Apparatus.read_apparatus(apparatus_id) do
      {:ok, %ApparatusReadModel{slug: slug}} when not is_nil(slug) -> slug
      _ -> nil
    end
  end

  defp equipment_slug(nil, instrument_id) when not is_nil(instrument_id) do
    case Instrument.read_instrument(instrument_id) do
      {:ok, %InstrumentReadModel{slug: slug}} when not is_nil(slug) -> slug
      _ -> nil
    end
  end

  defp equipment_slug(nil, nil), do: nil

  # A rename permutes the namespace a bound position lives in: the position keeps
  # its raw slug and moves under the equipment's new one, so its public path
  # always names the equipment's current slug. An edit that carries no slug left
  # the namespace where it was.
  #
  # No collision handling: equipment slugs are globally unique and a raw slug is
  # unique inside its equipment, so a rename cannot put two positions under one
  # path (`unique-slug-by-equipment`).
  defp rebind_namespace(multi, name, field, %{id: equipment_id, slug: equipment_slug} = _event) do
    case equipment_slug do
      nil ->
        multi

      equipment_slug ->
        Ecto.Multi.run(multi, name, fn repo, _changes ->
          rebind(repo, field, equipment_id, equipment_slug)
        end)
    end
  end

  defp rebind(repo, field, equipment_id, equipment_slug) do
    bound_positions =
      repo.all(from p in PositionReadModel, where: field(p, ^field) == ^equipment_id)

    Enum.reduce_while(bound_positions, {:ok, 0}, fn position, {:ok, moved} ->
      case repo.update(under_new_namespace(position, equipment_slug)) do
        {:ok, _position} -> {:cont, {:ok, moved + 1}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp under_new_namespace(%PositionReadModel{} = position, equipment_slug) do
    attrs = %{lookup_slug: canonical_path(position.slug, equipment_slug)}

    PositionReadModel.update_changeset(position, attrs)
  end
end
