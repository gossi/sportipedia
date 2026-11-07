defmodule SpGen.Blueprint.Controller do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/controller.md`
  — the Phoenix controller file itself.

  Generates the controller action for an ESDM **operation** (command or
  query): the controller module, created with this action when missing.

  Only GET (queries) and POST (commands) — every write is a command endpoint.
  The endpoint test lives in `SpGen.Blueprint.ControllerTest`,
  the route registration in `SpGen.Blueprint.WebRouter`.
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.{PublicAPI, ReadModel, Schema, View}

  @path "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_controller.ex"
  @module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Controller"
  @public_api_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>"
  @view_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @schemas "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas"

  def name, do: :controller
  def source_kinds, do: [:command, :query]
  def actor, do: :web
  def operations, do: [:create, :update, :delete, :read, :collection]
  def optional_template?, do: true

  @doc false
  def module_template, do: @module

  @doc "The controller's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)
  @doc false
  def public_api_template, do: @public_api_module
  @doc false
  def read_model_template, do: @read_model_module

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        module: Context.render(@module, ctx),
        units: units(ctx),
        unit_created: true
      }
    ]
  end

  defp bodyguard_plug(ctx) do
    "  plug Bodyguard.Plug.Authorize,\n" <>
      "    policy: #{Context.render(@public_api_module, ctx)}.Policy,\n" <>
      "    action: {Phoenix.Controller, :action_name},\n" <>
      "    user: {Sportipedia.Auth, :get_user_from_assigns},\n" <>
      "    fallback: FallbackController\n"
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
          requires: &op_gate/1,
          render: fn c ->
            c |> operation_block() |> String.trim_trailing()
          end,
          place: Merge.body_end()
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
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:use, "SportipediaWeb"},
        check: fn src -> Source.has_use?(src, "SportipediaWeb") end,
        render: fn _ctx -> "use SportipediaWeb, :controller" end,
        place: Merge.head(:use)
      },
      %Unit{
        id: {:use, "OpenApiSpex.ControllerSpecs"},
        check: fn src -> Source.has_use?(src, "OpenApiSpex.ControllerSpecs") end,
        render: fn _ctx -> "use OpenApiSpex.ControllerSpecs" end,
        place: Merge.head(:use)
      },
      %Unit{
        id: {:plug, "Bodyguard.Plug.Authorize"},
        check: fn src -> Source.entry?(src, :plug, "Bodyguard.Plug.Authorize") end,
        render: fn c -> c |> bodyguard_plug() |> String.trim_trailing() end,
        place: Merge.after_macro(:use, fn _ -> true end, Merge.head(:attribute))
      }
      # the collection parser belongs to list endpoints only
    ] ++
      query_parser_unit(ctx) ++
      [
        %Unit{
          id: :tags,
          check: fn src -> Source.entry?(src, :tags, tags_key(ctx)) end,
          render: fn c -> "tags [\"#{c.composite}\"]" end,
          place: Merge.after_macro(:plug, fn _ -> true end, Merge.body_end())
        },
        %Unit{
          id: {:alias, "OpenApiSpex.Reference"},
          check: fn src -> Source.has_alias?(src, "OpenApiSpex.Reference") end,
          render: fn _ctx -> "alias OpenApiSpex.Reference" end,
          place: Merge.alias_of("OpenApiSpex.Reference")
        },
        %Unit{
          id: {:alias, "SportipediaWeb.System.FallbackController"},
          check: fn src -> Source.has_alias?(src, "SportipediaWeb.System.FallbackController") end,
          render: fn _ctx -> "alias SportipediaWeb.System.FallbackController" end,
          place: Merge.alias_of("SportipediaWeb.System.FallbackController")
        },
        public_api_alias_unit(ctx)
      ]
  end

  defp query_parser_unit(ctx) do
    if Context.collection?(ctx) do
      [
        %Unit{
          id: {:plug, "JSONAPI.QueryParser"},
          check: fn src -> Source.entry?(src, :plug, "JSONAPI.QueryParser") end,
          render: fn c -> c |> query_parser_plug() |> String.trim_trailing() end,
          requires: fn c -> [{View.module_file(c), "view not generated (spgen view)"}] end,
          place: Merge.after_macro(:plug, fn _ -> true end, Merge.head(:attribute))
        }
      ]
    else
      []
    end
  end

  defp tags_key(ctx), do: "[\"#{ctx.composite}\"]"

  defp public_api_alias_unit(ctx) do
    module = Context.render(@public_api_module, ctx)

    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      place: Merge.alias_of(module)
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
        requires: alias_gate(tpl),
        place: Merge.alias_of(module)
      }
    end)
  end

  # the action body calls the public API; read actions also pattern-match the
  # read model struct
  defp op_gate(%Context{} = c) do
    base = [{PublicAPI.module_file(c), "public API not generated (spgen public_api)"}]

    if c.element.kind == :query and not Context.collection?(c) do
      base ++ [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}]
    else
      base
    end
  end

  # which citizen file each reference template resolves to
  defp alias_gate(tpl) do
    cond do
      tpl == @view_module ->
        fn c -> [{View.module_file(c), "view not generated (spgen view)"}] end

      tpl == @read_model_module ->
        fn c -> [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}] end

      tpl == "#{@schemas}.<DomainObject>CollectionResponse" ->
        fn c ->
          [{Schema.module_file(c, :collection_response), "schema not generated (spgen schema)"}]
        end

      tpl == "#{@schemas}.<DomainObject>Response" ->
        fn c -> [{Schema.module_file(c, :response), "schema not generated (spgen schema)"}] end

      tpl == "#{@schemas}.<Command>Request" ->
        fn c -> [{Schema.module_file(c, :request), "schema not generated (spgen schema)"}] end

      tpl == "#{@schemas}.<Operation>QueryParams" ->
        fn c ->
          [{Schema.module_file(c, :query_params), "schema not generated (spgen schema)"}]
        end

      true ->
        fn _c -> [] end
    end
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

  @doc "The full collection path of the constituent, e.g. `/catalog/equipment/apparatuses`."
  def collection_path(ctx), do: Context.render("/<-subdomain>/<-composite>/<domain-object>s", ctx)

  @doc "The endpoint route path, relative to the innermost scope."
  def route_path(ctx) do
    case {ctx.element.kind, ctx.operation} do
      {:command, _} -> "/" <> ctx.element.name
      {:query, _} -> if Context.collection?(ctx), do: "/", else: "/:#{Context.read_param(ctx)}"
    end
  end
end
