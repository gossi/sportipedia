defmodule Sportipedia.Codegen.Blueprints.Schema do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/schema.md`.

  OpenAPI schemas documenting the endpoints, driven by the element kind:

  * **read model** → `<DomainObject>Response` + `<DomainObject>CollectionResponse`
    (both derived from the JSON:API view via `OpenApiSchema.from_view/2`)
  * **command** (`create`/`update`) → `<Command>Request` derived from the
    command's data fields (the generated id is excluded; `delete` carries no
    request schema — its id rides in the body as `data.id`)
  * **query** (collection) → `<Operation>QueryParams` derived from the query's
    `parameters` (filter fields, sort, standard JSON:API page/fields)

  Every schema module is paired with its own ExUnit test file (structure
  assertions only — no DB).
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.View

  @dir "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas"
  @test_dir "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas"
  @ns "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas"
  @view_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
  @open_api_schema "Sportipedia.Support.JSONAPI.OpenApiSchema"

  def name, do: :schema
  def source_kinds, do: [:"read-model", :command, :query]
  def operations, do: [:create, :update, :delete, :read, :collection]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    case {ctx.element.kind, ctx.operation} do
      {:"read-model", _} ->
        whiches = [:response, :collection_response]
        Enum.flat_map(whiches, fn w -> [plan(ctx, w), test_plan(ctx, w)] end)

      {:command, op} when op in [:create, :update] ->
        [plan(ctx, :request), test_plan(ctx, :request)]

      {:query, _} ->
        if Context.collection?(ctx) and ctx.element.doc["parameters"] do
          [plan(ctx, :query_params), test_plan(ctx, :query_params)]
        else
          []
        end

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

  defp names(ctx, which) do
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
      path: Context.render("#{@dir}/" <> n[:stem] <> ".ex", ctx),
      role: :module,
      module: n[:full],
      scaffold: fn c -> scaffold(c, which, n) end,
      units: units(ctx, which)
    }
  end

  defp scaffold(ctx, which, n) do
    """
    defmodule #{n[:full]} do
      @moduledoc \"\"\"
      #{moduledoc(ctx, which)}
      \"\"\"

    #{body(ctx, which, n) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
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

  defp units(ctx, which) do
    require_unit() ++ alias_units(ctx, which)
  end

  defp require_unit do
    [
      %Unit{
        id: {:require, "OpenApiSpex"},
        check: fn src -> Source.has_require?(src, "OpenApiSpex") end,
        render: fn _ctx -> "require OpenApiSpex" end,
        anchor: fn src, _ctx ->
          Source.after_entry(
            src,
            :alias,
            fn _ -> true end,
            {:after_line, Source.module_start_line(src)}
          )
        end
      }
    ]
  end

  defp alias_units(ctx, which) when which in [:response, :collection_response] do
    [alias_unit(Context.render(@view_module, ctx)), alias_unit(@open_api_schema)]
  end

  defp alias_units(_ctx, _which), do: []

  defp alias_unit(module) do
    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      anchor: fn src, _ctx -> Source.alias_anchor(src, module) end,
      gap: :tight
    }
  end

  # ------------------------------------------------------------------- test

  @doc "The paired ExUnit test plan for one schema module."
  @spec test_plan(Context.t(), atom()) :: FilePlan.t()
  def test_plan(ctx, which) do
    n = names(ctx, which)

    %FilePlan{
      path: Context.render("#{@test_dir}/" <> n[:stem] <> "_test.exs", ctx),
      role: :test,
      module: n[:full] <> "Test",
      scaffold: fn _c -> test_scaffold(n) end,
      units: [
        %Unit{
          id: {:use, "ExUnit.Case"},
          check: fn src -> Source.has_use?(src, "ExUnit.Case") end,
          render: fn _ctx -> "use ExUnit.Case" end,
          anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
        },
        %Unit{
          id: {:alias, n[:full]},
          check: fn src -> Source.has_alias?(src, n[:full]) end,
          render: fn _ctx -> "alias #{n[:full]}" end,
          anchor: fn src, _ctx -> Source.alias_anchor(src, n[:full]) end,
          gap: :tight
        },
        %Unit{
          id: {:describe, n[:short]},
          check: fn src -> Source.has_describe?(src, n[:short]) end,
          render: fn _c -> test_describe(n) |> Templates.indent(2) end,
          anchor: fn src, _ctx -> Source.describe_anchor(src) end
        }
      ]
    }
  end

  defp test_scaffold(n) do
    """
    defmodule #{n[:full]}Test do
      use ExUnit.Case

      alias #{n[:full]}

    #{test_describe(n) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp test_describe(n) do
    """
    describe "#{n[:short]}" do
      test "schema/0 has the correct title" do
        assert %{title: "#{n[:title]}"} = #{n[:short]}.schema()
      end

      test "schema is an object" do
        assert %{type: :object} = #{n[:short]}.schema()
      end
    end
    """
  end
end
