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

  @test_path "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_endpoint_test.exs"
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
            requires: &fixture_seed_gate/1,
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

  # a fixture-seeded **query** test names the fixture and factory modules; it may
  # not be written before `sp.gen.test_support` created them. A command test
  # dispatches through the public API and references no fixture, so nothing gates.
  defp fixture_seed_gate(%Context{element: %Element{kind: :query}} = ctx) do
    case Context.fixture(ctx) do
      nil ->
        []

      fixture ->
        [
          {fixture.file, "the #{ctx.constituent} fixtures do not exist (spgen test_support)"},
          {fixture.seed_file,
           "the #{ctx.composite} test-support factory does not exist (spgen test_support)"}
        ]
    end
  end

  defp fixture_seed_gate(_ctx), do: []

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
    needs_read_model? = ctx.element.kind == :query or ctx.operation in [:delete, :none]

    base =
      [Controller.public_api_template()] ++
        if(needs_read_model?, do: [Controller.read_model_template()], else: [])

    # only the query tests seed a row through the fixture factory; commands
    # dispatch through the public API, so an unused alias there is a warning.
    if ctx.element.kind == :query and Context.fixtures?(ctx) do
      base ++ fixture_seed_aliases(ctx)
    else
      base
    end
  end

  # the fixture + factory modules the persisted seed names, so the test file
  # aliases every module its seed calls. Concrete dotted names — `test_scaffold`
  # renders them through `Context.render`, the identity for a template carrying
  # no placeholder.
  defp fixture_seed_aliases(ctx) do
    case Context.fixture(ctx) do
      nil ->
        []

      fixture ->
        [fixture.seed_module, fixture.module]
    end
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

      {:command, :none} ->
        [
          {"#{name} returns 204 for a valid payload", &none_happy/2},
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
    case ctx.operation do
      :update -> update_happy(ctx, name)
      _create -> create_happy(ctx, name)
    end
  end

  defp create_happy(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("#{Controller.collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", #{data_literal(ctx, ctx.element)})))

      body = json_response(conn, 200)

      assert jsonapi_type(body) == "#{ctx.constituent}"
    end
    """
  end

  # an update addresses an existing row: the golden pattern creates it first
  defp update_happy(ctx, name) do
    base = Controller.collection_path(ctx)
    create = create_command(ctx)
    {:ok, create_ctx} = Context.build(ctx.model, create)

    """
    test "#{name}", %{conn: conn} do
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("#{base}/#{create_ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", #{data_literal(create_ctx, create)})))

      catalog_body = json_response(catalog_conn, 200)
      id = jsonapi_id(catalog_body)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("#{base}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", #{data_literal(ctx, ctx.element)}, id)))

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
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

  # a `none` endpoint answers 204 straight from the dispatch — the payload is
  # the request, there is no row behind it
  defp none_happy(ctx, name) do
    """
    test "#{name}", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("#{Controller.collection_path(ctx)}/#{ctx.element.name}", Jason.encode!(jsonapi_body("#{ctx.constituent}", #{data_literal(ctx, ctx.element)})))

      assert conn.status == 204
      assert conn.resp_body == ""
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

      assert conn.status == 204
      assert conn.resp_body == ""
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
    #{Templates.indent(seed_block(ctx, "{:ok, %{id: id}}"), 6)}

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
    #{Templates.indent(seed_block(ctx, "{:ok, _}", :all), 6)}

      conn =
        conn
        |> api_conn()
        |> get("#{Controller.collection_path(ctx)}")

      body = json_response(conn, 200)

      assert is_list(body["data"])
    end
    """
  end

  # the write body: the happy feature scenario's `when.data` when the model
  # has one, else the command's required fields with type-correct samples
  defp data_literal(%Context{} = ctx, element) do
    case ctx.scenarios do
      [%{"when" => %{"data" => data}} | _] when map_size(data) > 0 ->
        "%{" <> Enum.map_join(data, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end) <> "}"

      _ ->
        unique = Context.unique_fields(ctx)

        element
        |> Esdm.fields()
        |> Enum.filter(&(&1.required and &1.name != "id"))
        |> Enum.map(fn f ->
          value =
            if f.name in unique do
              "\"sample-#{f.name}-\#{UUID.uuid4()}\""
            else
              Templates.sample_value(ctx, f)
            end

          "#{f.name}: #{value}"
        end)
        |> case do
          [] -> "%{}"
          parts -> "%{" <> Enum.join(parts, ", ") <> "}"
        end
    end
  end

  # The seed that places a row the endpoint **reads**. A read model has no
  # foreign-key enforcement, so fixture rows answer `read` and `collection` — the
  # aggregate and its referenced equipment are not involved.
  #
  # When the read model declares examples the rows are the model's fixtures,
  # seeded through the composite factory — the primary example for a single read
  # (`Equipment.new_widget(WidgetFixtures.classic_widget())`), every example for a
  # collection (`Equipment.new_widgets(WidgetFixtures.widgets())`), per the naming
  # doc's plural rule. Their `*Id` values are the `UUID.uuid5(:dns, <key>)` the
  # referenced fixture names itself with, so they are correct identifiers even
  # without the referenced row. Without examples there is no fixture to name —
  # seed through the create command, as before.
  defp seed_block(%Context{} = ctx, binding, mode \\ :one) do
    case Context.fixture(ctx) do
      nil ->
        "#{binding} = #{seed_expr(ctx)}"

      fixture ->
        seed =
          if mode == :all, do: Context.seed_all_expr(fixture), else: Context.seed_expr(fixture)

        "#{binding} = #{seed}"
    end
  end

  # the legacy fallback seed: seed through the constituent's create command, e.g.
  # `Apparatus.catalog_apparatus(%{title: "Vaulting Table", ...})`
  defp seed_expr(ctx) do
    case create_command(ctx) do
      nil ->
        raise "no create command for #{ctx.constituent} found to seed tests"

      cmd ->
        {:ok, create_ctx} = Context.build(ctx.model, cmd)
        api = Context.pascal(ctx.constituent)
        op = cmd.name |> String.replace("-", "_")
        "#{api}.#{op}(#{data_literal(create_ctx, cmd)})"
    end
  end

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
        Map.get(Esdm.declared_effects(rm), event_name) == :create
    end
  end
end
