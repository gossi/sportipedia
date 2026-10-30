defmodule SpGen.Blueprint.Schema do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/schema.md`
  — the OpenAPI schema module files.

  OpenAPI schemas documenting the endpoints, driven by the element kind:

  * **read model** → `<DomainObject>Response` + `<DomainObject>CollectionResponse`
    (both derived from the JSON:API view via `OpenApiSchema.from_view/2`)
  * **command** (`create`/`update`) → `<Command>Request` derived from the
    command's data fields (the generated id is excluded; `delete` carries no
    request schema — its id rides in the body as `data.id`)
  * **query** (collection) → `<Operation>QueryParams` derived from the query's
    `parameters` (filter fields, sort, standard JSON:API page/fields)

  Every schema module is paired with its own ExUnit test file
  (`SpGen.Blueprint.SchemaTest`).
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.View

  @dir "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas"
  @ns "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas"
  @view_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
  @open_api_schema "Sportipedia.Support.JSONAPI.OpenApiSchema"

  def name, do: :schema
  def source_kinds, do: [:"read-model", :command, :query]

  @doc "The schema module's file path for one role (used as a `requires` gate)."
  @spec module_file(Context.t(), atom()) :: String.t()
  def module_file(%Context{} = ctx, which) do
    n = names(ctx, which)
    Context.render("#{@dir}/" <> n[:stem] <> ".ex", ctx)
  end

  def operations, do: [:create, :update, :delete, :read, :collection]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    Enum.map(whiches(ctx), fn which -> plan(ctx, which) end)
  end

  @doc "The schema roles this element generates files for."
  @spec whiches(Context.t()) :: [atom()]
  def whiches(%Context{} = ctx) do
    case {ctx.element.kind, ctx.operation} do
      {:"read-model", _} ->
        [:response, :collection_response]

      {:command, op} when op in [:create, :update] ->
        [:request]

      {:query, _} ->
        if Context.collection?(ctx) and ctx.element.doc["parameters"],
          do: [:query_params],
          else: []

      _ ->
        []
    end
  end

  # ------------------------------------------------------------- definitions

  defp spec(:response),
    do: {"<domain_object>_response", "<DomainObject>Response", "<composite>.<DomainObject>"}

  defp spec(:collection_response),
    do:
      {"<domain_object>_collection_response", "<DomainObject>CollectionResponse",
       "<composite>.<DomainObject>s"}

  defp spec(:request),
    do: {"<_operation>_request", "<Command>Request", "<composite>.<Command>Request"}

  defp spec(:query_params),
    do:
      {"<_operation>_query_params", "<Operation>QueryParams",
       "<composite>.<Operation>QueryParams"}

  @doc "Stem/short/full/title names for one schema role."
  @spec names(Context.t(), atom()) :: %{
          stem: String.t(),
          short: String.t(),
          full: String.t(),
          title: String.t()
        }
  def names(ctx, which) do
    {stem_tpl, module_tpl, title_tpl} = spec(which)

    %{
      stem: Context.render(stem_tpl, ctx),
      short: Context.render(module_tpl, ctx),
      full: Context.render("#{@ns}.#{module_tpl}", ctx),
      title: Context.render(title_tpl, ctx)
    }
  end

  # ------------------------------------------------------------ plan: module

  defp plan(ctx, which) do
    n = names(ctx, which)

    %FilePlan{
      path: module_file(ctx, which),
      module: n[:full],
      units: units(ctx, which, n),
      unit_created: true
    }
  end

  defp moduledoc(ctx, which) do
    case which do
      :response ->
        "OpenAPI schema for documenting #{ctx.constituent} endpoints."

      :collection_response ->
        "OpenAPI schema for documenting #{ctx.constituent} collection endpoints."

      :request ->
        "OpenAPI schema for documenting the #{ctx.element.name} request parameters."

      :query_params ->
        "OpenAPI schema for documenting #{ctx.element.name} collection query parameters."
    end
  end

  # ------------------------------------------------------------------ bodies

  defp body(ctx, which, n) when which in [:response, :collection_response] do
    view_full = Context.render(@view_module, ctx)
    view_short = Context.pascal(ctx.constituent) <> "View"
    many = if which == :collection_response, do: ", many: true", else: ""
    what = if which == :response, do: "response", else: "collection response"

    """
    alias #{view_full}
    alias #{@open_api_schema}

    require OpenApiSpex

    @doc \"\"\"
    Returns the OpenAPI schema for the #{ctx.constituent} #{what}.
    \"\"\"
    OpenApiSpex.schema(
      OpenApiSchema.from_view(#{view_short}, title: "#{n[:title]}"#{many})
    )
    """
  end

  defp body(ctx, :request, n) do
    fields = Enum.reject(ctx.fields, & &1.internal)

    props =
      fields
      |> Enum.map(fn f ->
        nullable = if f.required, do: "", else: ", nullable: true"

        "      #{f.name}: %OpenApiSpex.Schema{type: #{openapi_type(f)}#{nullable}, " <>
          "description: #{inspect(f.description || "The #{f.name}")}}"
      end)
      |> Enum.join(",\n")

    required =
      fields
      |> Enum.filter(& &1.required)
      |> Enum.map(&":#{&1.name}")

    required_line =
      if required == [], do: "", else: ",\n      required: [#{Enum.join(required, ", ")}]"

    """
    require OpenApiSpex

    @doc \"\"\"
    Returns the OpenAPI schema for the #{ctx.element.name} request.
    \"\"\"
    OpenApiSpex.schema(%{
      title: "#{n[:title]}",
      type: :object,
      properties: %{
    #{props}
      }#{required_line}
    })
    """
  end

  defp body(ctx, :query_params, n) do
    params = Context.query_parameters(ctx)
    filter_props = get_in(params, ["filter", "properties"]) || %{}
    sortables = Map.keys(filter_props) |> Enum.sort()
    fields = View.view_fields(ctx) |> Enum.map(&String.trim_leading(&1, ":"))

    filter_body =
      filter_props
      |> Enum.map(fn {name, spec} ->
        desc = spec["description"] || "Filter #{ctx.constituent} by #{name} (partial match)"

        ~s|          #{name}: %OpenApiSpex.Schema{type: :string, description: #{inspect(desc)}}|
      end)
      |> Enum.join(",\n")

    sort_enum = sortables |> Enum.flat_map(&[&1, "-" <> &1]) |> Enum.map_join(", ", &inspect/1)
    fields_enum = Enum.map_join(fields, ", ", &inspect/1)

    """
    require OpenApiSpex

    @doc \"\"\"
    Returns the OpenAPI schema for the #{ctx.element.name} collection query parameters.
    \"\"\"
    OpenApiSpex.schema(%{
      title: "#{n[:title]}",
      type: :object,
      properties: %{
        filter: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
    #{filter_body}
          }
        },
        sort: %OpenApiSpex.Schema{
          type: :string,
          description: "Comma-separated fields to sort by. Prefix with `-` for descending.",
          enum: [#{sort_enum}]
        },
        page: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            number: %OpenApiSpex.Schema{type: :integer, default: 1},
            size: %OpenApiSpex.Schema{type: :integer, default: 20}
          }
        },
        fields: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            #{ctx.constituent}: %OpenApiSpex.Schema{
              type: :string,
              description: "Comma-separated fields to include in the response",
              enum: [#{fields_enum}]
            }
          }
        }
      }
    })
    """
  end

  defp openapi_type(%{type: "string"}), do: ":string"
  defp openapi_type(%{type: "integer"}), do: ":integer"
  defp openapi_type(%{type: "number"}), do: ":number"
  defp openapi_type(%{type: "boolean"}), do: ":boolean"
  defp openapi_type(_), do: ":string"

  # ------------------------------------------------------------------ units

  defp units(ctx, which, n) do
    view_gate = fn c -> [{View.module_file(c), "view not generated (spgen view)"}] end

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c -> "@moduledoc \"\"\"\n#{moduledoc(c, which)}\n\"\"\"" end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:require, "OpenApiSpex"},
        check: fn src -> Source.has_require?(src, "OpenApiSpex") end,
        render: fn _ctx -> "require OpenApiSpex" end,
        place: Merge.head(:require)
      }
    ] ++
      alias_units(ctx, which) ++
      [
        %Unit{
          id: :schema_body,
          check: fn src -> src.text =~ "OpenApiSpex.schema(" end,
          render: fn c -> body(c, which, n) |> String.trim_trailing() end,
          requires:
            if(which in [:response, :collection_response], do: view_gate, else: fn _c -> [] end),
          place: Merge.body_end()
        }
      ]
  end

  defp alias_units(ctx, which) when which in [:response, :collection_response] do
    [alias_unit(Context.render(@view_module, ctx)), alias_unit(@open_api_schema)]
  end

  defp alias_units(_ctx, _which), do: []

  defp alias_unit(module) do
    gate =
      if module == "Sportipedia.Support.JSONAPI.OpenApiSchema" do
        fn _c -> [] end
      else
        fn c -> [{View.module_file(c), "view not generated (spgen view)"}] end
      end

    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      requires: gate,
      place: Merge.alias_of(module)
    }
  end
end
