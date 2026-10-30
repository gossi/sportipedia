defmodule SpGen.Blueprint.ControllerTest do
  @moduledoc """
  The endpoint test file for one controller action
  (`docs/architecture/blueprints/backend/web/endpoint-test.md`): a
  `describe "<METHOD> <path>"` block per endpoint, tests following the status
  matrix — create 200/403, update 200/403, delete 204/404/403, read 200/404,
  collection 200.
  """

  use SpGen.Blueprint

  alias SpGen.{Esdm, Templates}
  alias SpGen.Esdm.Element
  alias SpGen.Blueprint.Controller

  @test_path "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_endpoint_test.exs"
  @test_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>EndpointTest"

  def plans(%Context{} = ctx) do
    subject = endpoint_subject(ctx)

    [
      %FilePlan{
        path: Context.render(@test_path, ctx),
        module: Context.render(@test_module, ctx),
        scaffold: &test_scaffold/1,
        units: [
          %Unit{
            id: {:use, "SportipediaWeb.ConnCase"},
            check: fn src -> Source.has_use?(src, "SportipediaWeb.ConnCase") end,
            render: fn _ctx -> "use SportipediaWeb.ConnCase" end,
            place: Merge.head(:use)
          },
          %Unit{
            id: {:import, "SportipediaWeb.RequestHelpers"},
            check: fn src -> Source.has_import?(src, "SportipediaWeb.RequestHelpers") end,
            render: fn _ctx -> "import SportipediaWeb.RequestHelpers" end,
            place: Merge.head(:import)
          },
          %Unit{
            id: {:describe, subject},
            check: fn src -> Source.has_describe?(src, subject) end,
            render: fn c -> endpoint_describe(c) end,
            place: Merge.describe()
          }
        ]
      }
    ]
  end

  @doc "The endpoint test's `describe` subject."
  def endpoint_subject(ctx) do
    base = Controller.collection_path(ctx)

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

    [Controller.public_api_template()] ++
      if needs_read_model?, do: [Controller.read_model_template()], else: []
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
        |> post("#{Controller.collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", #{scenario_literal(ctx)})))

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
        |> post("#{Controller.collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", %{})))

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
        |> post("#{Controller.collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", %{}, id)))

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
        |> post("#{Controller.collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", %{}, UUID.uuid4())))

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
        |> get("#{Controller.collection_path(ctx)}/\#{id}")

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
        |> get("#{Controller.collection_path(ctx)}/\#{UUID.uuid4()}")

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
        |> get("#{Controller.collection_path(ctx)}")

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
end
