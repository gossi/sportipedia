defmodule Sportipedia.Codegen.Blueprints.View do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/view.md`.

  Generates the JSON:API view for a **read model** element (and its own test
  file): `use JSONAPI.View` with the singular type, the resource `path/0`,
  and `fields/0` from the read model's schema (id and timestamps excluded —
  they are not attributes).
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, FilePlan, Source, Templates, Unit}

  @path "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_view.ex"
  @module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @test_path "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_view_test.exs"
  @test_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ViewTest"

  def name, do: :view
  def source_kinds, do: [:"read-model"]

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        role: :module,
        module: Context.render(@module, ctx),
        scaffold: &scaffold/1,
        units: units(ctx)
      },
      %FilePlan{
        path: Context.render(@test_path, ctx),
        role: :test,
        module: Context.render(@test_module, ctx),
        scaffold: &test_scaffold/1,
        units: test_units(ctx)
      }
    ]
  end

  @doc "Viewable attributes of the read model (no id, no timestamps)."
  def view_fields(%Context{} = ctx) do
    ctx.fields
    |> Enum.reject(&(&1.name in ["id", "inserted_at", "updated_at"]))
    |> Enum.map(&":#{&1.name}")
  end

  @doc "The JSON:API resource path, e.g. `catalog/equipment/apparatuses`."
  def view_path(%Context{} = ctx) do
    Context.render("<-subdomain>/<composite>/<domain-object>s", ctx)
  end

  defp scaffold(ctx) do
    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      Renders #{ctx.constituent} resources in JSON:API format.
      \"\"\"

      use JSONAPI.View, type: "#{ctx.constituent}"

      @doc \"\"\"
      Returns the path for #{ctx.constituent} resources.
      \"\"\"
      def path, do: "#{view_path(ctx)}"

      @doc \"\"\"
      Returns the fields for rendering a #{ctx.constituent}.
      \"\"\"
      def fields, do: [#{Enum.join(view_fields(ctx), ", ")}]
    end
    """
  end

  # ------------------------------------------------------------------- units

  defp units(_ctx) do
    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nRenders #{c.constituent} resources in JSON:API format.\n\"\"\""
        end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:use, "JSONAPI.View"},
        check: fn src -> Source.has_use?(src, "JSONAPI.View") end,
        render: fn c -> "use JSONAPI.View, type: \"#{c.constituent}\"" end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:def, :path, 0},
        check: fn src -> Source.has_def?(src, :path, 0) end,
        render: fn c -> "def path, do: \"#{view_path(c)}\"" end,
        anchor: fn src, _ctx -> Source.module_end_anchor(src) end
      },
      %Unit{
        id: {:def, :fields, 0},
        check: fn src -> Source.has_def?(src, :fields, 0) end,
        render: fn c -> "def fields, do: [#{Enum.join(view_fields(c), ", ")}]" end,
        anchor: fn src, _ctx -> Source.module_end_anchor(src) end
      }
    ]
  end

  # -------------------------------------------------------------------- test

  defp test_scaffold(ctx) do
    describes =
      [
        {"type/0", type_test(ctx)},
        {"fields/0", fields_test(ctx)},
        {"path/0", path_test(ctx)},
        {"render show.json", render_test(ctx)}
      ]
      |> Enum.map_join("\n\n", fn {subject, body} -> describe(subject, body) end)

    """
    defmodule #{Context.render(@test_module, ctx)} do
      use SportipediaWeb.ConnCase

      alias #{Context.render(@read_model_module, ctx)}
      alias #{Context.render(@module, ctx)}

    #{describes |> Templates.indent(2)}
    end
    """
  end

  defp describe(subject, body) do
    """
    describe "#{subject}" do
    #{body |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp test_units(ctx) do
    [
      %Unit{
        id: {:use, "SportipediaWeb.ConnCase"},
        check: fn src -> Source.has_use?(src, "SportipediaWeb.ConnCase") end,
        render: fn _ctx -> "use SportipediaWeb.ConnCase" end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      describe_unit("type/0", fn _ -> type_test(ctx) end),
      describe_unit("fields/0", fn _ -> fields_test(ctx) end),
      describe_unit("path/0", fn _ -> path_test(ctx) end),
      describe_unit("render show.json", fn _ -> render_test(ctx) end)
    ]
  end

  defp describe_unit(subject, body_fn) do
    %Unit{
      id: {:describe, subject},
      check: fn src -> Source.has_describe?(src, subject) end,
      render: fn _ctx -> describe(subject, body_fn.(nil)) |> Templates.indent(2) end,
      anchor: fn src, _ctx -> Source.describe_anchor(src) end
    }
  end

  defp type_test(ctx) do
    view = Context.pascal(ctx.constituent) <> "View"

    """
    test "returns #{ctx.constituent}" do
      assert #{view}.type() == "#{ctx.constituent}"
    end
    """
  end

  defp fields_test(ctx) do
    view = Context.pascal(ctx.constituent) <> "View"

    """
    test "returns the #{ctx.constituent} fields" do
      assert #{view}.fields() == [#{Enum.join(view_fields(ctx), ", ")}]
    end
    """
  end

  defp path_test(ctx) do
    view = Context.pascal(ctx.constituent) <> "View"

    """
    test "returns the #{ctx.constituent} path" do
      assert #{view}.path() == "#{view_path(ctx)}"
    end
    """
  end

  defp render_test(ctx) do
    view = Context.pascal(ctx.constituent) <> "View"
    read_model = Context.pascal(ctx.constituent) <> "ReadModel"

    attrs =
      ctx.fields
      |> Enum.reject(&(&1.name in ["id", "inserted_at", "updated_at"]))
      |> Enum.map(fn f -> "#{f.name}: \"sample-#{f.name}\"" end)
      |> Enum.join(", ")

    """
    test "produces JSON:API single document" do
      #{ctx.constituent} = %#{read_model}{id: "d290f1ee-6c54-4b01-90e6-d701748f0851", #{attrs}}

      conn = build_conn() |> fetch_query_params()

      result = #{view}.render("show.json", %{data: #{ctx.constituent}, conn: conn})

      assert %{data: %{id: "d290f1ee-6c54-4b01-90e6-d701748f0851", type: "#{ctx.constituent}"}} =
               result
    end
    """
  end
end
