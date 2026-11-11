defmodule Sportipedia.Catalog.Athlete.Position.Queries.PositionBySlugAndEquipment do
  @moduledoc """
  Query to fetch the position that already holds a raw slug inside one
  equipment namespace.

  The namespace is the `unique-slug-by-equipment` invariant's own reduction:
  positions bound to the same apparatus, positions bound to the same
  instrument, and the unbound positions — a namespace of its own, since no
  bound slug can ever equal a bare one.
  """

  import Ecto.Query
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Builds the query for one raw slug inside the namespace the two references
  name: an apparatus, an instrument, or — with both `nil` — the unbound
  namespace.
  """
  @spec new(String.t(), String.t() | nil, String.t() | nil) :: Ecto.Query.t()
  def new(raw_slug, apparatus_id, instrument_id) do
    namespace =
      cond do
        not is_nil(apparatus_id) -> dynamic([p], p.apparatusId == ^apparatus_id)
        not is_nil(instrument_id) -> dynamic([p], p.instrumentId == ^instrument_id)
        true -> dynamic([p], is_nil(p.apparatusId) and is_nil(p.instrumentId))
      end

    from p in PositionReadModel,
      where: p.raw_slug == ^raw_slug,
      where: ^namespace
  end
end
