defmodule Sportipedia.Catalog.Athlete.Position.Queries.ListPositions do
  @moduledoc """
  Query listing positions for the `list-positions` read.

  The base query carries the filtering the domain model names
  (`filter[title]`, a case-insensitive partial match). Sorting, pagination and
  sparse fieldsets of the JSON:API request are applied on top of it by
  `Sportipedia.Support.JSONAPI.QueryBuilder`, and `order_deterministically/1`
  closes the query for pagination.
  """
  import Ecto.Query

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Builds the query for a parsed JSON:API request configuration.
  """
  @spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
  def new(%JSONAPI.Config{} = config) do
    from(p in PositionReadModel)
    |> filter_by_title(Keyword.get(config.filter, :title))
  end

  defp filter_by_title(query, nil), do: query
  defp filter_by_title(query, term) when term == "", do: query

  defp filter_by_title(query, term) when is_binary(term) do
    pattern = "%#{literal_pattern(term)}%"

    from(p in query, where: ilike(p.title, ^pattern))
  end

  # `%` and `_` are LIKE wildcards. "partial match" means the caller's term is
  # literal text, so both are escaped before the term is wrapped in wildcards —
  # backslash first, or the escapes would escape themselves. PostgreSQL takes a
  # backslash as the LIKE escape character by default, and the pattern reaches it
  # as a bound parameter, so the backslashes arrive intact.
  defp literal_pattern(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  @doc """
  Appends the primary key as the last ordering key of a finished query.

  An unordered read has no stable pages: page two could repeat or skip a row it
  already showed. The key is appended, never prepended — `order_by` adds to the
  end, and a key in front of the caller's own sort would outrank it. For a
  request without a sort this is the only key, which is what makes the default
  order deterministic.
  """
  @spec order_deterministically(Ecto.Query.t()) :: Ecto.Query.t()
  def order_deterministically(query) do
    from(p in query, order_by: [asc: p.id])
  end
end
