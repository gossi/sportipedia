defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.ListApparatuses do
  @moduledoc """
  Query to list apparatuses with optional filtering, sorting, and pagination.
  """

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  import Ecto.Query

  @doc """
  Builds an Ecto query for listing apparatuses.

  ## Params
    - `filter` - map with optional `title` key for case-insensitive partial match
    - `sort` - list of sort fields (prefix `-` for descending), e.g. `["title"]` or `["-title"]`
    - `page` - map with `number` and `size` keys for pagination
  """
  @spec new(map()) :: Ecto.Query.t()
  def new(params \\ %{}) do
    ApparatusReadModel
    |> apply_filter(Map.get(params, :filter) || Map.get(params, "filter"))
    |> apply_sort(Map.get(params, :sort) || Map.get(params, "sort"))
    |> apply_pagination(Map.get(params, :page) || Map.get(params, "page"))
  end

  defp apply_filter(query, nil), do: query

  defp apply_filter(query, %{} = filters) do
    Enum.reduce(filters, query, fn {field, value}, q ->
      apply_single_filter(q, field, value)
    end)
  end

  defp apply_single_filter(query, "title", value) when is_binary(value) do
    where(query, [r], ilike(r.title, ^"%#{value}%"))
  end

  defp apply_single_filter(query, :title, value) when is_binary(value) do
    where(query, [r], ilike(r.title, ^"%#{value}%"))
  end

  defp apply_single_filter(query, _field, _value), do: query

  defp apply_sort(query, nil), do: query
  defp apply_sort(query, []), do: query

  defp apply_sort(query, sorts) when is_list(sorts) do
    Enum.reduce(sorts, query, fn sort_field, q ->
      {direction, field_name} = parse_sort_field(sort_field)
      order_by(q, [r], [{^direction, field(r, ^to_existing_field(field_name))}])
    end)
  end

  defp apply_sort(query, sort) when is_binary(sort) do
    {direction, field_name} = parse_sort_field(sort)
    order_by(query, [r], [{^direction, field(r, ^to_existing_field(field_name))}])
  end

  defp parse_sort_field("-" <> field), do: {:desc, field}
  defp parse_sort_field(field), do: {:asc, field}

  defp to_existing_field("title"), do: :title
  defp to_existing_field("slug"), do: :slug
  defp to_existing_field("description"), do: :description
  defp to_existing_field(field) when is_atom(field), do: field

  defp apply_pagination(query, nil), do: query
  defp apply_pagination(query, %{} = page) when map_size(page) == 0, do: query

  defp apply_pagination(query, %{"size" => size, "number" => number}) do
    {size, _} = parse_int(size, 20)
    {number, _} = parse_int(number, 1)
    offset = (max(number, 1) - 1) * size
    query |> limit(^size) |> offset(^offset)
  end

  defp apply_pagination(query, %{size: size, number: number}) do
    {size, _} = parse_int(size, 20)
    {number, _} = parse_int(number, 1)
    offset = (max(number, 1) - 1) * size
    query |> limit(^size) |> offset(^offset)
  end

  defp apply_pagination(query, %{"size" => size}) do
    {size, _} = parse_int(size, 20)
    limit(query, ^size)
  end

  defp apply_pagination(query, %{size: size}) do
    {size, _} = parse_int(size, 20)
    limit(query, ^size)
  end

  defp parse_int(value, default) when is_binary(value) do
    Integer.parse(value)
  rescue
    _ -> {default, ""}
  end

  defp parse_int(value, _default) when is_integer(value), do: {value, ""}
  defp parse_int(_, default), do: {default, ""}
end
