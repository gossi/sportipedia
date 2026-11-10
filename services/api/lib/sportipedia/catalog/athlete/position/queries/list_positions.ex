defmodule Sportipedia.Catalog.Athlete.Position.Queries.ListPositions do
  @moduledoc """
  List all positions with filtering, sorting, and pagination

  The collection is over the live read-model table: a position that left the
  catalog has no row to exclude.
  """
  import Ecto.Query

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Creates a new query to fetch positions.
  """
  @spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
  def new(%JSONAPI.Config{filter: filters, sort: sorts, page: page}) do
    PositionReadModel
    |> from(as: :resource)
    |> filter_by_title(filters)
    |> sort_by_public_attributes(sorts)
    |> paginate(page)
  end

  # The one filter the query states: a case-insensitive partial title match.
  defp filter_by_title(query, filters) when is_list(filters) do
    case Keyword.fetch(filters, :title) do
      {:ok, title} -> where(query, [resource], ilike(resource.title, ^"%#{title}%"))
      :error -> query
    end
  end

  defp filter_by_title(query, _filters), do: query

  # Clients sort by the attributes the view publishes. The published `slug` is the
  # canonical lookup path, so that order has to be taken here: the collection path's
  # QueryBuilder orders by the schema's own fields, which would sort the raw slug.
  defp sort_by_public_attributes(query, sorts) when is_list(sorts) do
    Enum.reduce(sorts, query, fn {direction, attribute}, sorted_query ->
      case sort_column(attribute) do
        nil -> sorted_query
        column -> order_by(sorted_query, [resource], [{^direction, field(resource, ^column)}])
      end
    end)
  end

  defp sort_by_public_attributes(query, _sorts), do: query

  defp sort_column(:title), do: :title
  defp sort_column(:slug), do: :lookup_slug
  defp sort_column(_attribute), do: nil

  # JSON:API pagination: `page[number]` is 1-based, `page[size]` the page length.
  defp paginate(query, %{"size" => size, "number" => number}) do
    size = page_size(size)
    offset = (max(page_number(number), 1) - 1) * size

    query
    |> limit(^size)
    |> offset(^offset)
  end

  defp paginate(query, %{"size" => size}) do
    limit(query, ^page_size(size))
  end

  defp paginate(query, _page), do: query

  defp page_size(size), do: positive_integer(size, 20)
  defp page_number(number), do: positive_integer(number, 1)

  defp positive_integer(value, default) do
    case "#{value}" |> Integer.parse() do
      {parsed, _rest} when parsed > 0 -> parsed
      _ -> default
    end
  end
end
