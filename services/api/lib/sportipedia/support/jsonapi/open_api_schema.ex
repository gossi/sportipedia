defmodule Sportipedia.Support.JSONAPI.OpenApiSchema do
  @moduledoc """
  Derives `OpenApiSpex.Schema`s from a `JSONAPI.View` module — the two halves of
  a JSON:API endpoint that a view already fully describes:

  * `from_view/2` — the response document (resource object, relationships, links)
  * `query_params/2` — a collection read's query parameters
    (`filter`/`sort`/`page`/`fields`)

  Both exist so an endpoint's document is *derived* instead of transcribed: the
  field lists of a JSON:API request otherwise live in three places — the domain
  model, the schema module, and the controller's `JSONAPI.QueryParser` options —
  and only the builder keeps them one fact.

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

  `from_view/2`:

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

  `query_params/2` — see its own `@doc` for `:filter`, `:sort`, `:page` and
  `:title`; `:title` is required there, because a collection's parameters belong
  to the operation, not to the resource type.

  ## Examples

      # Single resource
      OpenApiSchema.from_view(PostView)

      # Collection
      OpenApiSchema.from_view(PostView, many: true)

      # With options
      OpenApiSchema.from_view(PostView, title: "ArticleResponse", include_meta: false)

      # A collection read's query parameters
      OpenApiSchema.query_params(PostView,
        title: "blog.ListPostsQueryParams",
        filter: [title: "Filter posts by title (partial match)"],
        sort: ~w(title slug)
      )
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

  @doc """
  Builds the `OpenApiSpex.Schema` map documenting a JSON:API **collection read**'s
  query parameters: the four members `JSONAPI.QueryParser` validates and
  `Sportipedia.Support.JSONAPI.QueryBuilder` turns into an Ecto query.

  One call states what the whole request allows, so the filterable and sortable
  names live in the API document and the plug options rather than in a schema
  written out by hand. Members the caller names nothing for are left out: a
  collection that filters by nothing has no `filter` parameter to document.

  ## Options

  - `:filter` - keyword list of `field: "description"`, the fields the query
    allows filtering by (a partial, case-insensitive match for strings).
  - `:sort` - list of field names sortable in either direction; each is
    documented as `field` (ascending) and `-field` (descending).
  - `:page` - `:numbered` (`page[number]`/`page[size]`, the default), `:offset`
    (`page[limit]`/`page[offset]`), or `:none`.
  - `:title` - the schema title. Required: a collection's parameters belong to
    the operation, not to the resource type.

  The `fields` member (sparse fieldsets) is derived from the view — it is the
  view's own `fields/0`, the only list that says what a response may carry.

  ## Examples

      OpenApiSpex.schema(
        OpenApiSchema.query_params(PostView,
          title: "blog.ListPostsQueryParams",
          filter: [title: "Filter posts by title (partial match)"],
          sort: ~w(title slug),
          page: :numbered
        )
      )
  """
  @spec query_params(view :: JSONAPI.View.t(), opts :: keyword()) :: map()
  def query_params(view, opts) do
    title = Keyword.fetch!(opts, :title)

    properties =
      %{}
      |> put_member(:filter, filter_schema(Keyword.get(opts, :filter, [])))
      |> put_member(:sort, sort_schema(Keyword.get(opts, :sort, [])))
      |> put_member(:page, page_schema(Keyword.get(opts, :page, :numbered)))
      |> put_member(:fields, fields_schema(view))

    %{
      title: title,
      type: :object,
      properties: properties
    }
  end

  defp put_member(properties, _key, nil), do: properties
  defp put_member(properties, key, schema), do: Map.put(properties, key, schema)

  defp filter_schema([]), do: nil

  defp filter_schema(filters) do
    %Schema{
      type: :object,
      properties:
        Map.new(filters, fn {field, description} ->
          {field, %Schema{type: :string, description: description}}
        end)
    }
  end

  defp sort_schema([]), do: nil

  defp sort_schema(fields) do
    %Schema{
      type: :string,
      description: "Comma-separated fields to sort by. Prefix with `-` for descending.",
      enum: for(field <- fields, direction <- ["", "-"], do: direction <> to_string(field))
    }
  end

  defp page_schema(:none), do: nil

  defp page_schema(style) do
    %Schema{
      type: :object,
      properties:
        case style do
          :numbered ->
            %{
              number: %Schema{type: :integer, default: 1},
              size: %Schema{type: :integer, default: 20}
            }

          :offset ->
            %{
              limit: %Schema{type: :integer, default: 20},
              offset: %Schema{type: :integer, default: 0}
            }
        end
    }
  end

  defp fields_schema(view) do
    case view.fields() do
      [] ->
        nil

      fields ->
        # the view's `fields/0` names what a response may carry; the parameter is
        # a comma-separated *string*, so its enum holds strings, matching its type
        %Schema{
          type: :object,
          properties: %{
            String.to_atom(view.type()) => %Schema{
              type: :string,
              description: "Comma-separated fields to include in the response",
              enum: Enum.map(fields, &to_string/1)
            }
          }
        }
    end
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
