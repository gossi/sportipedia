defmodule Sportipedia.Support.JSONAPI.OpenApiSchema do
  @moduledoc """
  Derives an `OpenApiSpex.Schema` from a `JSONAPI.View` module.

  ## Usage

  Instead of hand-writing an OpenApiSpex schema that duplicates your view,
  call `from_view/2` to generate one at compile time:

      defmodule MyAppWeb.Schemas.PostResponse do
        require OpenApiSpex

        OpenApiSpex.schema(JSONAPI.OpenApiSchema.from_view(PostView))
      end

  Then reference it in your controller operation as usual:

      operation :show,
        responses: [
          ok: {"Post response", "application/vnd.api+json", MyAppWeb.Schemas.PostResponse}
        ]

  ## Options

  - `:many` - When `true`, wraps the `data` key as an array (for index actions).
    Defaults to `false`.
  - `:title` - Override the auto-derived schema title.
    Defaults to the view's `type/0` in PascalCase, e.g. `"PostResponse"`.
  - `:include_relationships` - When `false`, omits the `relationships` block.
    Defaults to `true`.
  - `:include_links` - When `false`, omits top-level and resource-level `links`.
    Defaults to `true`.
  - `:include_meta` - When `false`, omits `meta` fields.
    Defaults to `true`.

  ## Examples

      # Single resource
      OpenApiSchema.from_view(PostView)

      # Collection
      OpenApiSchema.from_view(PostView, many: true)

      # With options
      OpenApiSchema.from_view(PostView, title: "ArticleResponse", include_meta: false)
  """

  alias OpenApiSpex.Schema

  @doc """
  Builds an `OpenApiSpex.Schema` map from a `JSONAPI.View` module.

  The returned map is suitable for passing directly to `OpenApiSpex.schema/1`.
  """
  @spec from_view(view :: JSONAPI.View.t(), opts :: keyword()) :: map()
  def from_view(view, opts \\ []) do
    many? = Keyword.get(opts, :many, false)
    include_relationships? = Keyword.get(opts, :include_relationships, true)
    include_links? = Keyword.get(opts, :include_links, true)
    include_meta? = Keyword.get(opts, :include_meta, true)

    resource_type = view.type()
    title = Keyword.get(opts, :title, derive_title(resource_type, many?))

    %{
      title: title,
      description:
        "JSON:API #{if many?, do: "collection", else: "single resource"} response for #{resource_type}",
      type: :object,
      properties:
        Map.merge(
          %{
            data: data_schema(view, many?, include_relationships?, include_links?)
          },
          optional_top_level(include_links?, include_meta?)
        ),
      required: [:data]
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp derive_title(type, false), do: type |> pascal_case() |> Kernel.<>("Response")
  defp derive_title(type, true), do: type |> pascal_case() |> Kernel.<>("ListResponse")

  defp pascal_case(str) when is_binary(str) do
    str
    |> String.split(~r/[-_]/)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
  end

  defp pascal_case(nil), do: "Resource"

  # Top-level optional keys (links, meta)
  defp optional_top_level(include_links?, include_meta?) do
    []
    |> maybe_add(include_links?, :links, links_schema())
    |> maybe_add(include_meta?, :meta, meta_schema())
    |> Map.new()
  end

  # data: either a single resource object or an array
  defp data_schema(view, false = _many?, include_rels?, include_links?) do
    resource_object_schema(view, include_rels?, include_links?)
  end

  defp data_schema(view, true = _many?, include_rels?, include_links?) do
    %Schema{
      type: :array,
      items: resource_object_schema(view, include_rels?, include_links?)
    }
  end

  # The JSON:API resource object: { id, type, attributes, relationships?, links? }
  defp resource_object_schema(view, include_rels?, include_links?) do
    fields = view.fields()
    resource_type = view.type()
    relationships = view.relationships()

    attribute_props =
      fields
      |> Enum.reject(&(&1 == :id))
      |> Map.new(fn field -> {field, %Schema{type: :string, description: to_string(field)}} end)

    base_props = %{
      id: %Schema{type: :string, description: "Resource ID"},
      type: %Schema{type: :string, example: resource_type, description: "Resource type"}
    }

    attrs_schema = %Schema{
      type: :object,
      properties: attribute_props
    }

    props =
      base_props
      |> Map.put(:attributes, attrs_schema)
      |> maybe_put(
        include_rels? && relationships != [],
        :relationships,
        relationships_schema(relationships)
      )
      |> maybe_put(include_links?, :links, links_schema())

    %Schema{
      type: :object,
      properties: props,
      required: [:id, :type, :attributes]
    }
  end

  # Builds a `relationships` object schema from the view's relationship list.
  # Each relationship expands to a standard JSON:API linkage object.
  defp relationships_schema([]), do: nil

  defp relationships_schema(relationships) do
    props =
      Map.new(relationships, fn
        {name, {rel_view, _include_opt}} ->
          {name, relationship_object_schema(rel_view)}

        {name, rel_view} when is_atom(rel_view) ->
          {name, relationship_object_schema(rel_view)}

        {name, _other} ->
          {name, relationship_object_schema(nil)}
      end)

    %Schema{type: :object, properties: props}
  end

  defp relationship_object_schema(nil) do
    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string},
            type: %Schema{type: :string}
          },
          required: [:id, :type]
        }
      }
    }
  end

  defp relationship_object_schema(rel_view) do
    rel_type = try_type(rel_view)

    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string},
            type: %Schema{type: :string, example: rel_type}
          },
          required: [:id, :type]
        }
      }
    }
  end

  # Gracefully handle views that can't be resolved at schema-derivation time
  defp try_type(view) do
    view.type()
  rescue
    _ -> nil
  end

  defp links_schema do
    %Schema{
      type: :object,
      properties: %{
        self: %Schema{type: :string, format: :uri}
      }
    }
  end

  defp meta_schema do
    %Schema{
      type: :object,
      description: "Non-standard meta-information"
    }
  end

  defp maybe_add(list, true, key, value), do: [{key, value} | list]
  defp maybe_add(list, false, _key, _val), do: list

  defp maybe_put(map, true, key, value) when not is_nil(value), do: Map.put(map, key, value)
  defp maybe_put(map, _, _key, _value), do: map
end
