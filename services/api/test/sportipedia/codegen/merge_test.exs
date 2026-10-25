defmodule Sportipedia.Codegen.MergeTest do
  @moduledoc """
  Tree-merge machinery: whole-file print fidelity against real sources, and
  every placement strategy (`Sportipedia.Codegen.Merge` factories) —
  including the `:blocked` cases where the target structure is absent.
  """
  use ExUnit.Case, async: true

  alias Sportipedia.Codegen.{Formatter, Merge, Source, Unit}

  # __DIR__ = services/api/test/sportipedia/codegen → services/api
  @root Path.expand("../../..", __DIR__)

  defp read!(rel), do: Path.join(@root, rel) |> File.read!()
  defp ast!(rel), do: read!(rel) |> Sourceror.parse_string!()

  defp unit(text, place) do
    %Unit{id: :test, check: fn _ -> false end, render: fn _ -> text end, place: place}
  end

  defp merge!(rel, text, place) do
    u = unit(text, place)
    {:ok, ast} = u.place.(ast!(rel), u, nil)
    Merge.render(ast, Formatter.opts(@root))
  end

  defp line_of(text, needle) do
    text |> String.split("\n") |> Enum.find_index(&String.contains?(&1, needle))
  end

  # ------------------------------------------------------------- print fidelity

  describe "whole-file print round-trip (real sources)" do
    test "hand-written command.ex prints back byte-identical" do
      rel = "lib/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus/command.ex"
      assert Merge.render(ast!(rel), Formatter.opts(@root)) == read!(rel)
    end

    test "projector with fn blocks prints back byte-identical" do
      rel = "lib/sportipedia/catalog/equipment/apparatus/projector.ex"
      assert Merge.render(ast!(rel), Formatter.opts(@root)) == read!(rel)
    end

    test "web router with nested scopes prints back byte-identical" do
      assert Merge.render(ast!("lib/sportipedia_web/router.ex"), Formatter.opts(@root)) ==
               read!("lib/sportipedia_web/router.ex")
    end
  end

  # ----------------------------------------------------------------- placements

  describe "alias placement" do
    @command "lib/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus/command.ex"

    test "inserts into the alias block, above the first line of code" do
      rendered =
        merge!(
          @command,
          "alias Sportipedia.Catalog.Zed",
          Merge.alias_of("Sportipedia.Catalog.Zed")
        )

      src = Source.parse(rendered)
      assert Source.has_alias?(src, "Sportipedia.Catalog.Zed")

      assert line_of(rendered, "alias Sportipedia.Catalog.Zed") <
               line_of(rendered, "typedstruct do")
    end

    test "keeps aliases sorted" do
      rendered = merge!(@command, "alias Aaa", Merge.alias_of("Aaa"))
      assert line_of(rendered, "alias Aaa") < line_of(rendered, "alias Sportipedia.Catalog")
    end
  end

  describe "inside(typedstruct)" do
    @command "lib/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus/command.ex"

    test "appends a field inside the struct block" do
      rendered = merge!(@command, "field :capacity, :integer", Merge.inside(:typedstruct))
      assert Source.entry?(Source.parse(rendered), :field, ":capacity")
      assert line_of(rendered, "typedstruct do") < line_of(rendered, "field :capacity")
    end

    test "blocked when the block does not exist" do
      u = unit("field :x, :integer", Merge.inside(:typedstruct))
      assert :blocked = u.place.(ast!("lib/sportipedia_web/router.ex"), u, nil)
    end
  end

  describe "after_macro on the commanded router" do
    @router "lib/sportipedia/catalog/equipment/router.ex"

    test "dispatch lands after the last dispatch of its aggregate" do
      rendered =
        merge!(
          @router,
          "dispatch NewThing, to: NewThingHandler, aggregate: ApparatusAggregate",
          Merge.after_macro_kw(:dispatch, :aggregate, fn v -> v == "ApparatusAggregate" end)
        )

      assert Source.entry?(Source.parse(rendered), :dispatch, "NewThing")
      # appended below the apparatus cluster's last entry
      assert line_of(rendered, "dispatch ArchiveApparatus") <
               line_of(rendered, "dispatch NewThing")
    end

    test "identify lands after the dispatch cluster" do
      rendered =
        merge!(
          @router,
          "identify NewAggregate, by: :id, prefix: \"x/\"",
          Merge.after_macro(:dispatch, fn _ -> true end)
        )

      assert Source.entry?(Source.parse(rendered), :identify, "NewAggregate")

      assert line_of(rendered, "dispatch ArchiveInstrument") <
               line_of(rendered, "identify NewAggregate")
    end
  end

  describe "children_list" do
    @supervisor "lib/sportipedia/catalog/supervisor.ex"

    test "appends a child to the supervisor list" do
      rendered =
        merge!(
          @supervisor,
          "Sportipedia.Catalog.Equipment.Widget.WidgetProjector",
          Merge.children_list()
        )

      assert rendered =~ "Sportipedia.Catalog.Equipment.Widget.WidgetProjector"
      # still valid Elixir and the list is intact
      assert Source.has_child?(
               Source.parse(rendered),
               "Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector"
             )
    end

    test "blocked when there is no children list" do
      u = unit("Foo", Merge.children_list())
      assert :blocked = u.place.(ast!("lib/sportipedia/catalog/equipment/router.ex"), u, nil)
    end
  end

  describe "scope (web router)" do
    @real_router "lib/sportipedia_web/router.ex"
    @chain [
      {"/catalog", "SportipediaWeb.Catalog"},
      {"/equipment", "Equipment"},
      {"/apparatuses", "Apparatus"}
    ]

    test "route lands inside the deepest existing scope" do
      rendered =
        merge!(@real_router, "post \"/x-thing\", XController, :x_thing", Merge.scope(@chain))

      assert Source.route_present?(
               Source.parse(rendered),
               :post,
               ":x_thing",
               Enum.map(@chain, &elem(&1, 0))
             )
    end

    test "missing tail of the chain is materialized" do
      router = """
      defmodule SportipediaWeb.Router do
        scope "/catalog", SportipediaWeb.Catalog do
          scope "/gadgets", Gadgets do
            post "/y", YController, :y
          end
        end
      end
      """

      chain = [
        {"/catalog", "SportipediaWeb.Catalog"},
        {"/widgets", "Widget"}
      ]

      ast = Sourceror.parse_string!(router)
      u = unit("post \"/create-widget\", WidgetController, :create_widget", Merge.scope(chain))
      {:ok, ast} = u.place.(ast, u, nil)

      assert Merge.render(ast, Formatter.opts(@root)) =~ "scope \"/widgets\", Widget do"
    end

    test "blocked when the outermost scope is absent" do
      u = unit("post \"/x\", X, :x", Merge.scope(@chain))
      assert :blocked = u.place.(ast!("lib/sportipedia/catalog/equipment/router.ex"), u, nil)
    end
  end

  describe "clause and describe grouping" do
    @aggregate "lib/sportipedia/catalog/equipment/apparatus/aggregate.ex"

    test "after_def keeps apply/2 clauses together" do
      rendered =
        merge!(@aggregate, "def apply(_a, %Zz{}), do: :ok", Merge.after_def(:apply, 2))

      assert line_of(rendered, "def apply(_a, %Zz{})") > line_of(rendered, "def apply(%")
    end

    @op_test "test/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus_test.exs"

    test "describe appends after the last describe" do
      rendered =
        merge!(@op_test, "describe \"Zed\" do\n  test(\"t\", do: :ok)\nend", Merge.describe())

      assert Source.has_describe?(Source.parse(rendered), "Zed")

      assert line_of(rendered, "describe \"Zed\"") >
               line_of(rendered, "describe \"CatalogApparatus command\"")
    end

    test "before_helpers lands above the first defp" do
      src = """
      defmodule V do
        def a, do: :ok

        defp helper, do: :ok
      end
      """

      ast = Sourceror.parse_string!(src)
      u = unit("def b, do: :ok", Merge.before_helpers())
      {:ok, ast} = u.place.(ast, u, nil)
      rendered = Sourceror.to_string(ast)

      assert line_of(rendered, "def b") < line_of(rendered, "defp helper")
    end
  end

  describe "head ranks" do
    test "moduledoc first, use next, attributes after aliases" do
      src = """
      defmodule M do
        def go, do: :ok
      end
      """

      ast = Sourceror.parse_string!(src)
      alias_u = unit("alias A", Merge.alias_of("A"))
      {:ok, ast} = alias_u.place.(ast, alias_u, nil)

      use_u = unit("use ExUnit.Case", Merge.head(:use))
      {:ok, ast} = use_u.place.(ast, use_u, nil)

      doc_u = unit("@moduledoc \"hi\"", Merge.head(:moduledoc))
      {:ok, ast} = doc_u.place.(ast, doc_u, nil)

      attr_u = unit("@moduletag :integration", Merge.head(:attribute))
      {:ok, ast} = attr_u.place.(ast, attr_u, nil)

      rendered = Sourceror.to_string(ast)
      assert line_of(rendered, "@moduledoc") < line_of(rendered, "use ExUnit.Case")
      assert line_of(rendered, "use ExUnit.Case") < line_of(rendered, "alias A")
      assert line_of(rendered, "alias A") < line_of(rendered, "@moduletag")
      assert line_of(rendered, "@moduletag") < line_of(rendered, "def go")
    end
  end
end
