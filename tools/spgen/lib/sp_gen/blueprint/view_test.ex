defmodule SpGen.Blueprint.ViewTest do
  @moduledoc """
  The view's own test file (`<domain_object>_view_test.exs`): describes for
  `type/0`, `fields/0`, `path/0` and the `show.json` render — structure
  assertions against the view module and a read-model struct literal.
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.{ReadModel, View}

  @test_path "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_view_test.exs"
  @test_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ViewTest"

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@test_path, ctx),
        module: Context.render(@test_module, ctx),
        units: test_units(ctx),
        unit_created: true
      }
    ]
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
        place: Merge.head(:use)
      },
      describe_unit("type/0", fn -> type_test(ctx) end),
      describe_unit("fields/0", fn -> fields_test(ctx) end),
      describe_unit("path/0", fn -> path_test(ctx) end),
      describe_unit("render show.json", fn -> render_test(ctx) end)
    ] ++ alias_units(ctx)
  end

  # the render test references the view and the read model struct
  defp alias_units(ctx) do
    view = Context.render(View.module_template(), ctx)
    read_model = Context.render(ReadModel.module_template(), ctx)

    [
      %Unit{
        id: {:alias, view},
        check: fn src -> Source.has_alias?(src, view) end,
        render: fn _ctx -> "alias #{view}" end,
        place: Merge.alias_of(view)
      },
      %Unit{
        id: {:alias, read_model},
        check: fn src -> Source.has_alias?(src, read_model) end,
        render: fn _ctx -> "alias #{read_model}" end,
        requires: fn c ->
          [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}]
        end,
        place: Merge.alias_of(read_model)
      }
    ]
  end

  defp describe_unit(subject, body_fun) do
    %Unit{
      id: {:describe, subject},
      check: fn src -> Source.has_describe?(src, subject) end,
      render: fn _ctx -> describe(subject, body_fun.()) end,
      requires: fn c -> [{View.module_file(c), "view not generated (spgen view)"}] end,
      place: Merge.describe()
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
      assert #{view}.fields() == [#{Enum.join(View.view_fields(ctx), ", ")}]
    end
    """
  end

  defp path_test(ctx) do
    view = Context.pascal(ctx.constituent) <> "View"

    """
    test "returns the #{ctx.constituent} path" do
      assert #{view}.path() == "#{View.view_path(ctx)}"
    end
    """
  end

  defp render_test(ctx) do
    view = Context.pascal(ctx.constituent) <> "View"
    read_model = Context.pascal(ctx.constituent) <> "ReadModel"

    attrs =
      ctx.fields
      |> Enum.reject(&(&1.name in ["id", "inserted_at", "updated_at"]))
      |> Enum.map(fn f -> "#{f.name}: #{Templates.sample_value(ctx, f)}" end)
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
