defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.ListApparatuses do
  @moduledoc """
  Query to fetch apparatuses with filtering, sorting, and pagination.
  """

  import Ecto.Query

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  @doc """
  Creates a new query to fetch apparatuses.
  Applies the filter[title] condition (ilike partial match).
  Sorting and pagination are applied externally by JSONAPI.QueryBuilder.build/3.
  """
  @spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
  def new(%JSONAPI.Config{filter: filter}) do
    query = from(a in ApparatusReadModel, as: :resource)
    apply_title_filter(query, filter)
  end

  defp apply_title_filter(query, nil), do: query
  defp apply_title_filter(query, []), do: query

  defp apply_title_filter(query, filters) when is_list(filters) do
    title_value =
      Enum.find_value(filters, fn
        {"title", value} -> value
        {:title, value} -> value
        _ -> nil
      end)

    case title_value do
      nil -> query
      title -> where(query, [a], ilike(a.title, ^"%#{title}%"))
    end
  end
end
