defmodule Sportipedia.Codegen.Blueprints.Controller do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/controller.md`.

  Generates the Phoenix controller action for an ESDM **operation** (command
  or query): the controller module (created with this action when missing),
  the paired endpoint test file (per `endpoint-test.md`), and the route
  registration inside the web router's scope chain
  (`/«subdomain» → /«composite» → /«domain-object»s`).

  Only GET (queries) and POST (commands) — every write is a command endpoint.
  Status codes follow the endpoint-test matrix: create 200/403,
  update 200/403, delete 204/404/403, read 200/404, collection 200.

  Rendered text is flat; the project formatter restores indentation at the
  splice point (as it already does for aliases and fields).
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, Esdm, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Esdm.Element

  @path "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_controller.ex"
  @module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Controller"
  @public_api_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>"
  @view_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @schemas "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas"
  @router_path "services/api/lib/sportipedia_web/router.ex"
  @test_path "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_endpoint_test.exs"
  @test_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>EndpointTest"

  def name, do: :controller
  def source_kinds, do: [:command, :query]
  def operations, do: [:create, :update, :delete, :read, :collection]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    [controller_file(ctx), endpoint_test(ctx), router(ctx)]
  end

  # ------------------------------------------------------------- controller

  defp controller_file(ctx) do
    %FilePlan{
      path: Context.render(@path, ctx),
      role: :module,
      module: Context.render(@module, ctx),
      scaffold: &scaffold/1,
      units: units(ctx)
    }
  end

  defp scaffold(ctx) do
    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      Handles HTTP requests for #{ctx.constituent} operations.
      \"\"\"

      alias OpenApiSpex.Reference
      alias #{Context.render(@public_api_module, ctx)}
      alias SportipediaWeb.System.FallbackController

      use SportipediaWeb, :controller
      use OpenApiSpex.ControllerSpecs

    #{plug_block(ctx)}
      tags ["#{ctx.composite}"]

    #{operation_block(ctx) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp plug_block(ctx) do
    bodyguard =
      "  plug Bodyguard.Plug.Authorize,\n" <>
        "    policy: #{Context.render(@public_api_module, ctx)}.Policy,\n" <>
        "    action: {Phoenix.Controller, :action_name},\n" <>
        "    user: {Sportipedia.Auth, :get_user_from_assigns},\n" <>
        "    fallback: FallbackController\n"

    bodyguard <> query_parser_plug(ctx)
  end

  defp query_parser_plug(ctx) do
    if Context.collection?(ctx) do
      fields =
        ctx
        |> Context.query_parameters()
        |> get_in(["filter", "properties"])
        |> Kernel.||(%{})
        |> Map.keys()

      "  plug JSONAPI.QueryParser,\n" <>
        "    filter: ~w(#{Enum.join(fields, " ")}),\n" <>
        "    sort: ~w(#{Enum.join(fields, " ")}),\n" <>
        "    view: #{Context.pascal(ctx.constituent)}View\n"
    else
      ""
    end
  end

  # ------------------------------------------------------------------ units

  defp units(ctx) do
    op = String.to_atom(Context.op_snake(ctx))

    header_units(ctx) ++
      [
        %Unit{
          id: {:operation, op},
          check: fn src -> Source.has_def?(src, op, 2) end,
          render: fn c ->
            c |> operation_block() |> String.trim_trailing() |> Templates.indent(2)
          end,
          anchor: fn src, _ctx -> Source.module_end_anchor(src) end
        }
      ] ++
      op_alias_units(ctx)
  end

  defp header_units(ctx) do
    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nHandles HTTP requests for #{c.constituent} operations.\n\"\"\""
        end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:use, "SportipediaWeb"},
        check: fn src -> Source.has_use?(src, "SportipediaWeb") end,
        render: fn _ctx -> "use SportipediaWeb, :controller" end,
        anchor: fn src, _ctx ->
          Source.after_entry(
            src,
            :alias,
            fn _ -> true end,
            {:after_line, Source.module_start_line(src)}
          )
        end
      },
      %Unit{
        id: {:use, "OpenApiSpex.ControllerSpecs"},
        check: fn src -> Source.has_use?(src, "OpenApiSpex.ControllerSpecs") end,
        render: fn _ctx -> "use OpenApiSpex.ControllerSpecs" end,
        anchor: fn src, _ctx ->
          Source.after_entry(
            src,
            :use,
            fn _ -> true end,
            {:after_line, Source.module_start_line(src)}
          )
        end
      },
      %Unit{
        id: {:plug, "Bodyguard.Plug.Authorize"},
        check: fn src -> Source.entry?(src, :plug, "Bodyguard.Plug.Authorize") end,
        render: fn c -> c |> plug_block() |> String.trim_trailing() end,
        anchor: fn src, _ctx ->
          Source.after_entry(
            src,
            :use,
            fn _ -> true end,
            {:after_line, Source.module_start_line(src)}
          )
        end
      },
      %Unit{
        id: :tags,
        check: fn src -> Source.entry?(src, :tags, tags_key(ctx)) end,
        render: fn c -> "tags [\"#{c.composite}\"]" end,
        anchor: fn src, _ctx ->
          Source.after_entry(src, :plug, fn _ -> true end, Source.module_end_anchor(src))
        end
      },
      %Unit{
        id: {:alias, "OpenApiSpex.Reference"},
        check: fn src -> Source.has_alias?(src, "OpenApiSpex.Reference") end,
        render: fn _ctx -> "alias OpenApiSpex.Reference" end,
        anchor: fn src, _ctx -> Source.alias_anchor(src, "OpenApiSpex.Reference") end,
        gap: :tight
      },
      %Unit{
        id: {:alias, "SportipediaWeb.System.FallbackController"},
        check: fn src -> Source.has_alias?(src, "SportipediaWeb.System.FallbackController") end,
        render: fn _ctx -> "alias SportipediaWeb.System.FallbackController" end,
        anchor: fn src, _ctx ->
          Source.alias_anchor(src, "SportipediaWeb.System.FallbackController")
        end,
        gap: :tight
      },
      public_api_alias_unit(ctx)
    ]
  end

  defp tags_key(ctx), do: "[\"#{ctx.composite}\"]"

  defp public_api_alias_unit(ctx) do
    module = Context.render(@public_api_module, ctx)

    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      anchor: fn src, _ctx -> Source.alias_anchor(src, module) end,
      gap: :tight
    }
  end

  # aliases the operation block references; presence of the action itself
  # counts as satisfied (a human may have merged the block manually)
  defp op_alias_units(ctx) do
    op = String.to_atom(Context.op_snake(ctx))

    ctx
    |> op_aliases()
    |> Enum.map(fn tpl ->
      module = Context.render(tpl, ctx)

      %Unit{
        id: {:alias, module},
        check: fn src -> Source.has_alias?(src, module) or Source.has_def?(src, op, 2) end,
        render: fn _ctx -> "alias #{module}" end,
        anchor: fn src, _ctx -> Source.alias_anchor(src, module) end,
        gap: :tight
      }
    end)
  end

  defp op_aliases(ctx) do
    view = @view_module
    response = "#{@schemas}.<DomainObject>Response"
    request = "#{@schemas}.<Command>Request"
    collection = "#{@schemas}.<DomainObject>CollectionResponse"
    params = "#{@schemas}.<Operation>QueryParams"
    read_model = @read_model_module

    case {ctx.element.kind, ctx.operation} do
      {:command, :delete} ->
        []

      {:command, _} ->
        [view, response, request]

      {:query, _} ->
        if Context.collection?(ctx),
          do: [view, collection, params],
          else: [view, read_model, response]
    end
  end

  # -------------------------------------------------------- operation block

  @doc "The `operation` spec, `@spec` and action clause for one endpoint."
  @spec operation_block(Context.t()) :: String.t()
  def operation_block(ctx) do
    op = Context.op_snake(ctx)
    api = Context.pascal(ctx.constituent)

    header = """
    @doc \"\"\"
    Handles the #{ctx.element.name} request.
    \"\"\"
    #{operation_spec(ctx)}
    """

    """
    #{String.trim_trailing(header)}

    @spec #{op}(Plug.Conn.t(), map()) :: Plug.Conn.t()
    def #{op}(conn, _) do
    #{action_body(ctx, op, api) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp operation_spec(ctx) do
    op = Context.op_snake(ctx)
    summary = ctx.element.doc["description"] || "TODO: describe the #{ctx.element.name} operation"
    responses = responses(ctx) |> Enum.map(fn r -> "        " <> r end) |> Enum.join(",\n")

    """
    operation :#{op},
      summary: "#{summary}",#{spec_params(ctx)}
      responses: [
    #{responses}
      ]
    """
    |> String.trim_trailing()
  end

  defp spec_params(ctx) do
    cond do
      ctx.element.kind == :command and ctx.operation != :delete ->
        request = Context.pascal(ctx.element.name) <> "Request"

        "\n      request_body: {\"The #{ctx.constituent} attributes\", \"application/json\", #{request}},"

      ctx.element.kind == :query and Context.collection?(ctx) ->
        params = Context.pascal(ctx.element.name) <> "QueryParams"
        "\n      parameters: [\n        query: [in: :query, schema: #{params}]\n      ],"

      ctx.element.kind == :query ->
        param = Context.read_param(ctx)

        "\n      parameters: [\n        #{param}: [in: :path, description: \"The #{ctx.constituent} #{String.replace(param, "_", " or ")}\", type: :string]\n      ],"

      true ->
        ""
    end
  end

  defp responses(ctx) do
    response = Context.pascal(ctx.constituent) <> "Response"

    case {ctx.element.kind, ctx.operation} do
      {:command, :delete} ->
        [
          "no_content: \"The #{ctx.constituent} has been archived\"",
          ref("not_found"),
          ref("unauthorized"),
          ref("forbidden")
        ]

      {:command, _} ->
        [
          ~s|ok: {"The #{ctx.constituent}", "application/vnd.api+json", #{response}}|,
          ref("unprocessable_entity"),
          ref("unauthorized"),
          ref("forbidden")
        ]

      {:query, _} ->
        if Context.collection?(ctx) do
          collection = Context.pascal(ctx.constituent) <> "CollectionResponse"

          [
            ~s|ok: {"#{Context.pascal(ctx.constituent)} collection", "application/vnd.api+json", #{collection}}|
          ]
        else
          [
            ~s|ok: {"The #{ctx.constituent}", "application/vnd.api+json", #{response}}|,
            ref("not_found")
          ]
        end
    end
  end

  defp ref(name), do: ~s|#{name}: %Reference{"$ref": "#/components/responses/#{name}"}|

  defp action_body(ctx, op, api) do
    view = Context.pascal(ctx.constituent) <> "View"
    var = ctx.constituent

    case {ctx.element.kind, ctx.operation} do
      {:command, :delete} ->
        """
        case #{api}.#{op}(conn.params["id"]) do
          :ok ->
            send_resp(conn, :no_content, "")

          {:error, errors} ->
            {:error, errors}
        end
        """

      {:command, _} ->
        """
        with {:ok, #{var}} <- #{api}.#{op}(conn.params) do
          conn
          |> put_view(json: #{view})
          |> render("show.json", %{data: #{var}})
        end
        """

      {:query, _} ->
        if Context.collection?(ctx) do
          """
          case #{api}.#{op}(conn.assigns.jsonapi_query) do
            {:ok, data} ->
              conn
              |> put_view(json: #{view})
              |> render("index.json", %{data: data})
          end
          """
        else
          rm = Context.pascal(ctx.constituent) <> "ReadModel"
          param = Context.read_param(ctx)

          """
          case #{api}.#{op}(conn.params["#{param}"]) do
            {:ok, %#{rm}{} = #{var}} ->
              conn
              |> put_view(json: #{view})
              |> render("show.json", %{data: #{var}})

            {:error, :not_found} ->
              {:error, :not_found}
          end
          """
        end
    end
    |> String.trim_trailing()
  end

  # -------------------------------------------------------- endpoint test

  defp endpoint_test(ctx) do
    subject = endpoint_subject(ctx)

    %FilePlan{
      path: Context.render(@test_path, ctx),
      role: :test,
      module: Context.render(@test_module, ctx),
      scaffold: &test_scaffold/1,
      units: [
        %Unit{
          id: {:use, "SportipediaWeb.ConnCase"},
          check: fn src -> Source.has_use?(src, "SportipediaWeb.ConnCase") end,
          render: fn _ctx -> "use SportipediaWeb.ConnCase" end,
          anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
        },
        %Unit{
          id: {:import, "SportipediaWeb.RequestHelpers"},
          check: fn src -> Source.has_import?(src, "SportipediaWeb.RequestHelpers") end,
          render: fn _ctx -> "import SportipediaWeb.RequestHelpers" end,
          anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
        },
        %Unit{
          id: {:describe, subject},
          check: fn src -> Source.has_describe?(src, subject) end,
          render: fn c -> c |> endpoint_describe() |> Templates.indent(2) end,
          anchor: fn src, _ctx -> Source.describe_anchor(src) end
        }
      ]
    }
  end

  @doc "The full collection path of the constituent, e.g. `/catalog/equipment/apparatuses`."
  def collection_path(ctx), do: Context.render("/<-subdomain>/<-composite>/<domain-object>s", ctx)

  @doc "The endpoint route path, relative to the innermost scope."
  def route_path(ctx) do
    case {ctx.element.kind, ctx.operation} do
      {:command, _} -> "/" <> ctx.element.name
      {:query, _} -> if Context.collection?(ctx), do: "/", else: "/:#{Context.read_param(ctx)}"
    end
  end

  @doc "The endpoint test's `describe` subject."
  def endpoint_subject(ctx) do
    base = collection_path(ctx)

    case {ctx.element.kind, ctx.operation} do
      {:command, _} ->
        "POST #{base}/#{ctx.element.name}"

      {:query, _} ->
        if Context.collection?(ctx) do
          "GET #{base} (#{ctx.element.name})"
        else
          "GET #{base}/:#{Context.read_param(ctx)} (#{ctx.element.name})"
        end
    end
  end

  defp test_scaffold(ctx) do
    aliases =
      ctx
      |> test_alias_templates()
      |> Enum.map(&Context.render(&1, ctx))
      |> Enum.map(&"  alias #{&1}")
      |> Enum.join("\n")

    """
    defmodule #{Context.render(@test_module, ctx)} do
      use SportipediaWeb.ConnCase

      import SportipediaWeb.RequestHelpers

    #{aliases}

    #{endpoint_describe(ctx) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp test_alias_templates(ctx) do
    needs_read_model? = ctx.element.kind == :query or ctx.operation == :delete
    [@public_api_module] ++ if needs_read_model?, do: [@read_model_module], else: []
  end

  defp endpoint_describe(ctx) do
    subject = endpoint_subject(ctx)

    tests =
      ctx
      |> endpoint_tests()
      |> Enum.map(fn {name, fun} -> fun.(ctx, name) end)

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end

  @doc "The endpoint tests for this operation, per the blueprint status matrix."
  def endpoint_tests(ctx) do
    name = ctx.element.name

    case {ctx.element.kind, ctx.operation} do
      {:command, :delete} ->
        [
          {"#{name} returns 204 for a cataloged #{ctx.constituent}", &delete_happy/2},
          {"returns 404 for an unknown id", &delete_missing/2},
          {"returns 403 when unauthenticated", &unauthenticated/2}
        ]

      {:command, _} ->
        [
          {"#{name} returns 200 with the #{ctx.constituent}", &write_happy/2},
          {"returns 403 when unauthenticated", &unauthenticated/2}
        ]

      {:query, _} ->
        if Context.collection?(ctx) do
          [{"returns 200 with a collection of #{ctx.constituent}s", &collection_happy/2}]
        else
          [
            {"returns 200 with the #{ctx.constituent} when found", &read_happy/2},
            {"returns 404 when the #{ctx.constituent} does not exist", &read_missing/2}
          ]
        end
    end
  end

  defp write_happy(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("#{collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", #{scenario_literal(ctx)})))

      body = json_response(conn, 200)

      assert jsonapi_type(body) == "#{ctx.constituent}"
    end
    """
  end

  defp unauthenticated(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post("#{collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", %{})))

      assert json_response(conn, 403)
    end
    """
  end

  defp delete_happy(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      {:ok, %{id: id}} = #{seed_expr(ctx)}

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("#{collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", %{}, id)))

      assert json_response(conn, 204)
    end
    """
  end

  defp delete_missing(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("#{collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", %{}, UUID.uuid4())))

      assert json_response(conn, 404)
    end
    """
  end

  defp read_happy(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      {:ok, %{id: id}} = #{seed_expr(ctx)}

      conn =
        conn
        |> api_conn()
        |> get("#{collection_path(ctx)}/\#{id}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end
    """
  end

  defp read_missing(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("#{collection_path(ctx)}/#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end
    """
  end

  defp collection_happy(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      {:ok, _} = #{seed_expr(ctx)}

      conn =
        conn
        |> api_conn()
        |> get("#{collection_path(ctx)}")

      body = json_response(conn, 200)

      assert is_list(body["data"])
    end
    """
  end

  # data literal from the operation's happy feature scenario (`when.data`)
  defp scenario_literal(ctx) do
    case ctx.scenarios do
      [%{"when" => %{"data" => data}} | _] when map_size(data) > 0 ->
        "%{" <> Enum.map_join(data, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end) <> "}"

      _ ->
        "%{}"
    end
  end

  # seed through the constituent's create command, e.g.
  # `Apparatus.catalog_apparatus(%{title: "Vaulting Table", ...})`
  defp seed_expr(ctx) do
    case create_command(ctx) do
      nil ->
        raise "no create command for #{ctx.constituent} found to seed tests"

      cmd ->
        api = Context.pascal(ctx.constituent)
        op = cmd.name |> String.replace("-", "_")
        data = cmd |> scenarios_for(ctx.model) |> literal_for(cmd)
        "#{api}.#{op}(#{data})"
    end
  end

  defp literal_for([], _cmd), do: "%{}"

  defp literal_for([scenario | rest], cmd) do
    case get_in(scenario, ["when", "data"]) do
      data when map_size(data) > 0 ->
        "%{" <> Enum.map_join(data, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end) <> "}"

      _ ->
        literal_for(rest, cmd)
    end
  end

  defp scenarios_for(cmd, model), do: Esdm.scenarios(model, cmd)

  defp create_command(ctx) do
    ctx.model.elements
    |> Enum.filter(fn el ->
      el.kind == :command and Element.aggregate_name(el) == ctx.constituent
    end)
    |> Enum.find(fn el -> el |> Esdm.publishes() |> Enum.any?(&creates_row?(ctx, &1)) end)
  end

  defp creates_row?(ctx, event_name) do
    case ctx.read_model do
      nil ->
        false

      rm ->
        rm
        |> Esdm.projections()
        |> Enum.find(&(&1["event"] == event_name))
        |> case do
          nil -> false
          projection -> Esdm.projection_effect(projection) == :create
        end
    end
  end

  # ----------------------------------------------------- router registration

  defp router(ctx) do
    %FilePlan{
      path: @router_path,
      role: :registration,
      module: "SportipediaWeb.Router",
      scaffold: nil,
      units: [route_unit(ctx)]
    }
  end

  @doc false
  def route_unit(ctx) do
    op = Context.op_snake(ctx)
    verb = if ctx.element.kind == :command, do: :post, else: :get
    chain = scope_chain(ctx)
    controller = Context.pascal(ctx.constituent) <> "Controller"
    line = "#{verb} \"#{route_path(ctx)}\", #{controller}, :#{op}"

    %Unit{
      id: {:route, ":#{op}"},
      check: fn src -> Source.route_present?(src, verb, ":#{op}", chain) end,
      render: fn _ctx -> line end,
      text_for: fn src, c ->
        case Source.deepest_scope(src, chain) do
          {:ok, _scope, depth} when depth < length(chain) ->
            route_scope_text(chain, depth, line, c)

          _ ->
            nil
        end
      end,
      anchor: fn src, _ctx ->
        case Source.deepest_scope(src, chain) do
          {:ok, scope, _depth} -> {:before_line, scope.end_line}
          :none -> :no_block
        end
      end,
      gap: :tight
    }
  end

  @doc "The scope-chain path strings for this constituent's endpoints."
  def scope_chain(ctx) do
    ["/" <> ctx.subdomain, "/" <> ctx.composite, "/" <> ctx.constituent <> "s"]
  end

  @doc """
  Render the missing tail of the scope chain (from `depth` in) wrapping the
  route line. The formatter fixes indentation after splicing.
  """
  @spec route_scope_text([String.t()], pos_integer(), String.t(), Context.t()) :: String.t()
  def route_scope_text(chain, depth, route_line, ctx) do
    chain
    |> Enum.slice(depth..-1//1)
    |> Enum.reverse()
    |> Enum.reduce(route_line, fn path, inner ->
      "scope \"#{path}\", #{scope_alias(path, ctx)} do\n#{inner}\nend"
    end)
  end

  defp scope_alias(path, ctx) do
    name = String.trim_leading(path, "/")

    cond do
      name == ctx.subdomain -> "SportipediaWeb." <> Context.pascal(name)
      name == ctx.constituent <> "s" -> Context.pascal(ctx.constituent)
      true -> Context.pascal(name)
    end
  end
end
