defmodule Sportipedia.Catalog.Athlete.Position.Queries.ListPositions do
  @moduledoc """
  List all positions with filtering, sorting, and pagination
  """
  import Ecto.Query

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Creates a new query to fetch positions.

  The parameters are the ones the `list-positions` query states: `filter.title`
  as a case-insensitive partial match, `sort` following JSON:API sort syntax,
  and `page` (`number` and `size`) following JSON:API pagination.

  The answer holds the positions currently in the catalog: a position that left
  it has no row here, so nothing filters it out.
  """
  @spec new(map()) :: Ecto.Query.t()
  def new(params) do
    PositionReadModel
    |> filter_by_title(params)
    |> sorted_by(params)
    |> paginated_by(params)
  end

  defp filter_by_title(query, params) do
    case title_filter(params) do
      nil ->
        query

      term ->
        where(query, [position], ilike(position.title, ^"%#{term}%"))
    end
  end

  defp title_filter(params) do
    with %{} = filter <- param(params, "filter"), do: param(filter, "title")
  end

  defp sorted_by(query, params) do
    params
    |> sort_terms()
    |> Enum.reduce(query, &apply_sort_term(&2, &1))
  end

  # JSON:API sort syntax: comma-separated field names, `-` for descending.
  defp sort_terms(params) do
    case param(params, "sort") do
      nil ->
        []

      sort_spec ->
        sort_spec
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.map(&sort_term/1)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp sort_term("-" <> field), do: sortable(field, :desc)
  defp sort_term(field), do: sortable(field, :asc)

  defp sortable(field, direction) do
    case to_existing_atom(String.trim(field)) do
      nil ->
        nil

      attribute ->
        if attribute in PositionReadModel.__schema__(:fields), do: {direction, attribute}
    end
  end

  defp to_existing_atom(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> nil
  end

  defp apply_sort_term(query, {direction, attribute}) do
    order_by(query, [position], [{^direction, field(position, ^attribute)}])
  end

  # JSON:API pagination: the page size bounds the window, the 1-based page
  # number moves it. Without a size there is no window to take.
  defp paginated_by(query, params) do
    page = param(params, "page") || %{}

    case integer_param(page, "size") do
      nil ->
        query

      size when size < 1 ->
        query

      size ->
        number = max(integer_param(page, "number") || 1, 1)

        query
        |> offset(^((number - 1) * size))
        |> limit(^size)
    end
  end

  defp integer_param(params, key) do
    case param(params, key) do
      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {integer, _rest} -> integer
          :error -> nil
        end

      _ ->
        nil
    end
  end

  # A parameter of the model, read from a map keyed either by strings, as an
  # HTTP request delivers them, or by atoms, as an Elixir caller writes them.
  defp param(params, key) when is_map(params) do
    case Map.fetch(params, key) do
      {:ok, value} when not is_nil(value) -> value
      _ -> Map.get(params, String.to_atom(key))
    end
  end

  defp param(_params, _key), do: nil
end
