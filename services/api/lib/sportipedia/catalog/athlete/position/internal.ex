defmodule Sportipedia.Catalog.Athlete.Position.PositionInternal do
  @moduledoc """
  Internal API for querying position read models within the bounded context.
  """
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Athlete.Position.Queries.PositionBySlugAndEquipment
  alias Sportipedia.Catalog.Repo

  @doc """
  Fetches a position by its ID. Returns nil if not found.
  """
  @spec position_by_id(String.t()) :: PositionReadModel.t() | nil
  def position_by_id(id) do
    Repo.get(PositionReadModel, id)
  end

  @doc """
  Fetches the position that already owns a raw slug inside one equipment
  namespace, or `nil` when the namespace is free.

  The two references name the namespace: an apparatus, an instrument, or — both
  `nil` — the unbound positions. The raw slug is lowered before the lookup,
  because the canonical form the write side stores is lowercase.
  """
  @spec position_by_slug_and_equipment(String.t(), String.t() | nil, String.t() | nil) ::
          PositionReadModel.t() | nil
  def position_by_slug_and_equipment(slug, apparatus_id, instrument_id) do
    slug
    |> String.downcase()
    |> PositionBySlugAndEquipment.new(apparatus_id, instrument_id)
    |> Repo.one()
  end
end
