defmodule Sportipedia.Support.JSONAPI.QueryBuilder do
  @moduledoc """
  Converts a JSONAPI.Config struct into an Ecto query.
  Handles filtering, sorting, pagination (page-based and offset-based),
  and sparse fieldsets (select).
  """

  import Ecto.Query

  @doc """
  Builds an Ecto query from a JSONAPI.Config and an Ecto schema module.

  ## Parameters
    - config: A %JSONAPI.Config{} struct (from the `jsonapi` library)
    - schema: An Ecto schema module (e.g. MyApp.Post)

  ## Examples
      iex> config = JSONAPI.Config.process(conn, MyApp.PostView)
      iex> query = JSONAPIQuery.build(config, MyApp.Post)
      iex> Repo.all(query)
  """
  @spec build(JSONAPI.Config.t(), module()) :: Ecto.Query.t()
  def build(%JSONAPI.Config{} = config, schema) when is_atom(schema) do
    schema
    |> from(as: :resource)
    |> apply_filter(config.filter, schema)
    |> apply_sort(config.sort, schema)
    |> apply_pagination(config.page)
    |> apply_fields(config.fields, config.view, schema)
  end

  @doc """
  Builds an Ecto query from a base query, a JSONAPI.Config, and an Ecto schema module.
  Applies sorting, pagination, and sparse fieldsets on top of the base query.
  Filtering is expected to be already applied in the base query.

  ## Parameters
    - config: A %JSONAPI.Config{} struct (from the `jsonapi` library)
    - base_query: A pre-built Ecto.Query (e.g. from a custom query module)
    - schema: An Ecto schema module (e.g. MyApp.Post)

  ## Examples
      iex> base_query = MyCustomQuery.new(config)
      iex> query = JSONAPIQuery.build(config, base_query, MyApp.Post)
      iex> Repo.all(query)
  """
  @spec build(JSONAPI.Config.t(), Ecto.Query.t(), module()) :: Ecto.Query.t()
  def build(%JSONAPI.Config{} = config, %Ecto.Query{} = base_query, schema)
      when is_atom(schema) do
    base_query
    |> apply_sort(config.sort, schema)
    |> apply_pagination(config.page)
    |> apply_fields(config.fields, config.view, schema)
  end

  # ---------------------------------------------------------------------------
  # Filtering
  # ---------------------------------------------------------------------------

  defp apply_filter(query, nil, _schema), do: query

  defp apply_filter(query, filters, schema) when is_list(filters) do
    Enum.reduce(filters, query, fn {field, value}, q ->
      apply_single_filter(q, field, value, schema)
    end)
  end

  defp apply_single_filter(query, field, value, schema) do
    atom_field = to_existing_atom(field)

    cond do
      not valid_field?(schema, atom_field) ->
        query

      # Range filters: "field[gt]", "field[gte]", "field[lt]", "field[lte]"
      is_map(value) ->
        Enum.reduce(value, query, fn {op, v}, q ->
          apply_range_filter(q, atom_field, op, cast_value(schema, atom_field, v))
        end)

      # List filter: comma-separated values -> IN clause
      is_binary(value) and String.contains?(value, ",") ->
        values = value |> String.split(",") |> Enum.map(&String.trim/1)

        if string_field?(schema, atom_field) do
          where(
            query,
            [r],
            fragment("lower(?)", field(r, ^atom_field)) in ^Enum.map(values, &String.downcase/1)
          )
        else
          where(query, [r], field(r, ^atom_field) in ^values)
        end

      # Exact match (case-insensitive for string/text fields)
      true ->
        cast_val = cast_value(schema, atom_field, value)

        if string_field?(schema, atom_field) do
          where(
            query,
            [r],
            fragment("lower(?) LIKE ?", field(r, ^atom_field), ^"%#{String.downcase(cast_val)}%")
          )
        else
          where(query, [r], field(r, ^atom_field) == ^cast_val)
        end
    end
  end

  defp apply_range_filter(query, field, "gt", value),
    do: where(query, [r], field(r, ^field) > ^value)

  defp apply_range_filter(query, field, "gte", value),
    do: where(query, [r], field(r, ^field) >= ^value)

  defp apply_range_filter(query, field, "lt", value),
    do: where(query, [r], field(r, ^field) < ^value)

  defp apply_range_filter(query, field, "lte", value),
    do: where(query, [r], field(r, ^field) <= ^value)

  defp apply_range_filter(query, _field, _op, _value), do: query

  # ---------------------------------------------------------------------------
  # Sorting
  # ---------------------------------------------------------------------------

  defp apply_sort(query, nil, _schema), do: query
  defp apply_sort(query, [], _schema), do: query

  defp apply_sort(query, sorts, schema) when is_list(sorts) do
    Enum.reduce(sorts, query, fn sort_field, q ->
      {direction, field_name} = parse_sort_field(sort_field)
      atom_field = to_existing_atom(field_name)

      if valid_field?(schema, atom_field) do
        order_by(q, [r], [{^direction, field(r, ^atom_field)}])
      else
        q
      end
    end)
  end

  defp parse_sort_field("-" <> field), do: {:desc, field}
  defp parse_sort_field(field), do: {:asc, field}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  defp apply_pagination(query, nil), do: query
  defp apply_pagination(query, page) when page == %{}, do: query

  defp apply_pagination(query, %{"size" => size, "number" => number}) do
    {size, _} = parse_int(size, 20)
    {number, _} = parse_int(number, 1)
    offset = (max(number, 1) - 1) * size
    query |> limit(^size) |> offset(^offset)
  end

  defp apply_pagination(query, %{"limit" => limit, "offset" => offset}) do
    {limit, _} = parse_int(limit, 20)
    {offset, _} = parse_int(offset, 0)
    query |> limit(^limit) |> offset(^offset)
  end

  defp apply_pagination(query, %{"size" => size}) do
    {size, _} = parse_int(size, 20)
    limit(query, ^size)
  end

  defp apply_pagination(query, _page), do: query

  # ---------------------------------------------------------------------------
  # Sparse Fieldsets
  # ---------------------------------------------------------------------------

  defp apply_fields(query, nil, _view, _schema), do: query
  defp apply_fields(query, fields, nil, _schema) when fields == %{}, do: query

  defp apply_fields(query, fields, view, schema) do
    type = if view, do: view.type(), else: nil

    requested =
      cond do
        type && Map.has_key?(fields, type) ->
          fields[type]

        Map.has_key?(fields, schema_type_key(schema)) ->
          fields[schema_type_key(schema)]

        true ->
          nil
      end

    case requested do
      nil ->
        query

      field_list when is_list(field_list) ->
        valid_atoms =
          field_list
          |> Enum.map(&to_existing_atom/1)
          |> Enum.filter(&valid_field?(schema, &1))

        if valid_atoms == [] do
          query
        else
          # Always include :id for Ecto
          select_fields = Enum.uniq([:id | valid_atoms])
          select(query, [r], map(r, ^select_fields))
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp valid_field?(schema, field) when is_atom(field) do
    field in schema.__schema__(:fields)
  rescue
    _ -> false
  end

  defp cast_value(schema, field, value) when is_binary(value) do
    type = schema.__schema__(:type, field)
    cast_typed_value(type, value)
  end

  defp cast_value(_schema, _field, value), do: value

  defp cast_typed_value(:integer, v), do: String.to_integer(v)
  defp cast_typed_value(:float, v), do: String.to_float(v)
  defp cast_typed_value(:boolean, "true"), do: true
  defp cast_typed_value(:boolean, "false"), do: false
  defp cast_typed_value(_, v), do: v

  defp to_existing_atom(value) when is_atom(value), do: value

  defp to_existing_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp schema_type_key(schema) do
    schema
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp string_field?(schema, field) do
    type = schema.__schema__(:type, field)
    type in [:string, :text]
  end

  defp parse_int(value, default) when is_binary(value) do
    Integer.parse(value)
  rescue
    _ -> {default, ""}
  end

  defp parse_int(value, _default) when is_integer(value), do: {value, ""}
  defp parse_int(_, default), do: {default, ""}
end
