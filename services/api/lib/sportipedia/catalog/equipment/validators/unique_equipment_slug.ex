defmodule Sportipedia.Catalog.Equipment.Validators.UniqueEquipmentSlug do
  @moduledoc """
  Validates that a slug is unique within the pool of all equipment slugs
  (apparatuses and instruments together). Models the `unique-equipment-slug`
  invariant of the apparatus and instrument aggregates: one rule for the pool,
  so one validator shared by both constituents' commands.

  The record that already owns the value passes (the edit case): the validator
  compares the found row's `id` against `context.id`. An absent value is not
  the validator's business — the command's `allow_nil` decides that.
  """

  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal

  @doc """
  Validates the given slug value for uniqueness within the equipment slug pool.
  """
  @spec validate(String.t() | nil, map()) :: :ok | {:error, atom()}
  def validate(nil, _context), do: :ok

  def validate(value, context) do
    case equipment_by_slug(value) do
      nil ->
        :ok

      equipment ->
        if slug_owned_by_context?(equipment, context), do: :ok, else: {:error, :slug_exists}
    end
  end

  defp equipment_by_slug(slug) do
    ApparatusInternal.apparatus_by_slug(slug) || InstrumentInternal.instrument_by_slug(slug)
  end

  defp slug_owned_by_context?(equipment, context) do
    Map.get(context, :id) == equipment.id
  end
end
